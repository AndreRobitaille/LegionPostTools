require "test_helper"
require "timeout"

class MobileRenewalConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @organization = Organization.create!(name: "Synthetic renewal Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @person = Person.create!(first_name: "Renewal", last_name: "Caller")
    @user = User.create!(person: @person, email_address: "renewal-#{SecureRandom.hex(8)}@example.test")
    @user.permission_grants.create!(capability: "use_mobile_buddy_checks")
    @application = Doorkeeper::Application.create!(name: "Synthetic renewal", redirect_uri: "org.example.buddy:/callback", scopes: "buddy_check", confidential: false)
    @old_env = ENV.to_h.slice("MOBILE_BUDDY_CHECK_ENABLED", "MOBILE_BUDDY_CHECK_CLIENT_ID", "MOBILE_BUDDY_CHECK_ISSUER")
    ENV["MOBILE_BUDDY_CHECK_ENABLED"] = "true"
    ENV["MOBILE_BUDDY_CHECK_CLIENT_ID"] = @application.uid
    ENV["MOBILE_BUDDY_CHECK_ISSUER"] = "http://www.example.com"
    @installation = Installation.singleton
    @setup_completed_at = @installation.setup_completed_at
    @installation.update!(setup_completed_at: Time.current)
    sign_in_as(@user)
    verifier = SecureRandom.urlsafe_base64(48)
    post "/oauth/authorize", params: { client_id: @application.uid, redirect_uri: @application.redirect_uri,
      response_type: "code", scope: "buddy_check", state: SecureRandom.hex(32), remember_session: "180_days",
      code_challenge_method: "S256", code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }
    assert_response :redirect
    code = URI.decode_www_form(URI.parse(response.location).query).to_h.fetch("code")
    @code_request = { grant_type: "authorization_code", client_id: @application.uid, redirect_uri: @application.redirect_uri,
      code: code, code_verifier: verifier, exchange_id: SecureRandom.uuid }
    @connection = Mobile::RememberedSession.find_by!(application_id: @application.id)
    @threads = []
  end

  teardown do
    @threads.each { |thread| raise "Renewal request remained active" unless thread.join(20) }
    ids = Mobile::RememberedSession.where(application_id: @application.id).pluck(:id)
    Mobile::TokenExchange.where(remembered_session_id: ids).delete_all
    Mobile::RefreshCredential.where(remembered_session_id: ids).delete_all
    Doorkeeper::AccessToken.where(application_id: @application.id).delete_all
    Doorkeeper::AccessGrant.where(application_id: @application.id).delete_all
    Mobile::RememberedSession.where(id: ids).delete_all
    @application.destroy!
    @person.destroy!
    @organization.destroy!
    @installation.update!(setup_completed_at: @setup_completed_at)
    %w[MOBILE_BUDDY_CHECK_ENABLED MOBILE_BUDDY_CHECK_CLIENT_ID MOBILE_BUDDY_CHECK_ISSUER].each do |key|
      @old_env.key?(key) ? ENV[key] = @old_env[key] : ENV.delete(key)
    end
  end

  test "simultaneous identical authorization exchanges issue one recoverable credential pair" do
    results = overlap(@code_request, @code_request)
    assert_equal [ 200, 200 ], results.map(&:first)
    assert_equal 1, results.map { |_, body| body.fetch("refresh_token") }.uniq.size
    assert_equal 1, @connection.access_tokens.count
    assert_equal 1, @connection.refresh_credentials.count
    assert_equal 1, @connection.token_exchanges.count
  end

  test "simultaneous identical renewals serialize on independent connections and return one successor" do
    first = issue_initial
    request = refresh_request(first)
    results = overlap(request, request)
    assert_equal [ 200, 200 ], results.map(&:first)
    assert_equal 1, results.map { |_, body| body.fetch("access_token") }.uniq.size
    assert_equal 1, results.map { |_, body| body.fetch("refresh_token") }.uniq.size
    assert_equal 2, @connection.access_tokens.count
    assert_equal 2, @connection.refresh_credentials.count
    assert_equal 1, @connection.refresh_credentials.where(consumed_at: nil).count
    assert_nil @connection.reload.revoked_at
  end

  test "competing renewals with different identities detect reuse and revoke the winner too" do
    first = issue_initial
    results = overlap(refresh_request(first), refresh_request(first))
    assert_equal [ 200, 400 ], results.map(&:first).sort
    assert_equal "refresh_reuse_detected", results.find { |status, _| status == 400 }.last["error_code"]
    winner = results.find { |status, _| status == 200 }.last
    get "/api/mobile/v1/session", headers: { "Authorization" => "Bearer #{winner.fetch('access_token')}" }
    assert_response :unauthorized
    assert_equal "refresh_reuse_detected", response.parsed_body.dig("error", "code")
    assert_equal 2, @connection.access_tokens.count
    assert_empty @connection.access_tokens.where(revoked_at: nil)
  end

  test "a renewal waiting behind website disable sees the committed loss of access" do
    first = issue_initial
    thread = nil
    @user.with_lock do
      observer = ActiveRecord::Base.connection
      blocker = observer.select_value("SELECT pg_backend_pid()")
      @user.update!(disabled_at: Time.current, disabled_reason: "manual")
      thread, pid = start_request(refresh_request(first))
      await_database_state { blocking_pids(observer, pid).include?(blocker) }
    end
    assert thread.join(20)
    status, body = thread.value
    assert_equal 400, status
    assert_equal "account_unavailable", body["error_code"]
    assert_equal 1, @connection.access_tokens.count
    get "/api/mobile/v1/session", headers: { "Authorization" => "Bearer #{first.fetch('access_token')}" }
    assert_response :unauthorized
    assert_equal "account_unavailable", response.parsed_body.dig("error", "code")
  end

  private

  def issue_initial
    post "/oauth/token", params: @code_request
    assert_response :success
    response.parsed_body
  end

  def refresh_request(credentials)
    { grant_type: "refresh_token", client_id: @application.uid,
      refresh_token: credentials.fetch("refresh_token"), exchange_id: SecureRandom.uuid }
  end

  def overlap(first_request, second_request)
    requests = nil
    @connection.with_lock do
      observer = ActiveRecord::Base.connection
      observer_pid = observer.select_value("SELECT pg_backend_pid()")
      requests = [ start_request(first_request), start_request(second_request) ]
      pids = requests.map(&:last)
      assert_equal 3, ([ observer_pid ] + pids).uniq.size
      await_database_state do
        pids.all? { |pid| (blocking_pids(observer, pid) & ([ observer_pid ] + pids)).any? }
      end
    end
    requests.map do |thread, _|
      assert thread.join(20), "Request did not finish after releasing its real database lock"
      thread.value
    end
  end

  def start_request(params)
    ready = Queue.new
    thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET statement_timeout = '15s'")
        ready << connection.select_value("SELECT pg_backend_pid()")
        client = ActionDispatch::Integration::Session.new(Rails.application)
        client.post "/oauth/token", params: params
        [ client.response.status, client.response.parsed_body ]
      ensure
        connection.execute("SET statement_timeout = DEFAULT")
      end
    end
    @threads << thread
    [ thread, Timeout.timeout(10) { ready.pop } ]
  end

  def blocking_pids(connection, pid)
    connection.uncached { connection.select_values("SELECT unnest(pg_blocking_pids(#{Integer(pid)}))") }
  end

  def await_database_state
    Timeout.timeout(10) { sleep 0.01 until yield }
  end
end
