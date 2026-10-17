require "test_helper"
require_relative "../support/buddy_checks_helpers"

class MobileRememberedAuthenticationTest < ActionDispatch::IntegrationTest
  include BuddyChecksHelpers

  setup do
    setup_buddy_checks
    @verifier = SecureRandom.urlsafe_base64(48)
    @authorization = { client_id: @mobile_client.uid, response_type: "code", scope: "buddy_check",
      redirect_uri: @mobile_client.redirect_uri, state: SecureRandom.hex(32), remember_session: "180_days",
      code_challenge_method: "S256", code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(@verifier), padding: false) }
  end
  teardown { restore_buddy_configuration }

  test "explicit remembered consent issues a short access token and a fixed duration connection" do
    travel_to Time.utc(2026, 10, 12, 20) do
      exchange = authorization_exchange
      post "/oauth/token", params: exchange
      assert_response :success
      credentials = response.parsed_body
      assert credentials["refresh_token"].present?, "Remembered consent must issue a renewal credential"
      assert_equal 900, credentials["expires_in"]
      assert_equal "buddy_check", credentials["scope"]
      assert_equal ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER"), credentials["issuer"]
      assert_equal @organization.id, credentials["installation_id"]
      assert_equal @other.id, credentials["user_id"]
      assert_equal Time.current, Time.iso8601(credentials.fetch("authorized_at"))
      assert_equal Time.current + 180.days, Time.iso8601(credentials.fetch("remembered_until"))
      assert_equal Time.current + 15.minutes, Time.iso8601(credentials.fetch("expires_at"))
      get "/api/mobile/v1/session", headers: bearer(credentials)
      assert_response :success
      assert_equal true, response.parsed_body.dig("capabilities", "refresh")
      assert_equal credentials["session_id"], response.parsed_body["session_id"]
      assert_equal credentials["remembered_session_id"], response.parsed_body["remembered_session_id"]
      assert_equal credentials["remembered_until"], response.parsed_body["remembered_until"]
    end
  end

  test "real email sign-in preserves the opt-in and shows explicit remembered consent" do
    get "/oauth/authorize", params: @authorization
    assert_redirected_to new_session_path
    link = MagicLink.create_for!(@other)
    post magic_link_session_path, params: { token: link.token }
    follow_redirect!
    assert_response :success
    assert_select "input[name='remember_session'][value='180_days']"
    assert_select "form[action='/oauth/authorize'] button[type='submit']", text: "Connect and remember this sign-in"
    assert_includes response.body, "up to 180 days"
    assert_equal "strict-origin", response.headers["Referrer-Policy"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal 0, Mobile::RememberedSession.count
  end

  test "legacy and forged token-endpoint opt-ins remain nonrenewable" do
    @authorization.delete(:remember_session)
    @authorization[:remembered_session_id] = 123
    exchange = authorization_exchange
    post "/oauth/token", params: exchange.merge(remember_session: "180_days", remembered_session_id: 123)
    assert_response :success
    credentials = response.parsed_body
    assert_nil credentials["refresh_token"]
    get "/api/mobile/v1/session", headers: bearer(credentials)
    assert_response :success
    assert_equal false, response.parsed_body.dig("capabilities", "refresh")
    assert_not response.parsed_body.key?("remembered_session_id")
    assert_equal 0, Mobile::RememberedSession.count
    get "/oauth/authorize", params: @authorization.merge(remember_session: "forever")
    assert_response :bad_request
  end

  test "rotation preserves identity and deadline while ordinary access expiry permits renewal" do
    travel_to Time.utc(2026, 10, 12, 20) do
      first = issue_credentials
      travel 14.minutes
      second = renew(first)
      assert_not_equal first["access_token"], second["access_token"]
      assert_not_equal first["refresh_token"], second["refresh_token"]
      assert_not_equal first["session_id"], second["session_id"]
      %w[remembered_session_id authorized_at remembered_until issuer user_id installation_id].each do |field|
        assert_equal first[field], second[field], field
      end
      get "/api/mobile/v1/session", headers: bearer(first)
      assert_response :success
      travel 2.minutes
      get "/api/mobile/v1/session", headers: bearer(first)
      assert_api_error "expired_session", :unauthorized
      get "/api/mobile/v1/session", headers: bearer(second)
      assert_response :success
      travel 14.minutes
      get "/api/mobile/v1/session", headers: bearer(second)
      assert_api_error "expired_session", :unauthorized
      third = renew(second)
      get "/api/mobile/v1/session", headers: bearer(third)
      assert_response :success
      assert_equal 3, Mobile::RefreshCredential.count
      assert_equal 1, Mobile::RefreshCredential.where(consumed_at: nil).count
    end
  end

  test "the exact elapsed 180-day deadline crosses daylight saving and caps the final access token" do
    travel_to Time.utc(2026, 1, 1, 20) do
      first = issue_credentials
      deadline = Time.current + 15_552_000
      assert_equal deadline, Time.iso8601(first.fetch("remembered_until"))
      travel_to deadline - 45
      final = renew(first)
      assert_equal 45, final["expires_in"]
      assert_equal deadline, Time.iso8601(final.fetch("expires_at"))
      travel_to deadline
      get "/api/mobile/v1/session", headers: bearer(final)
      assert_api_error "remembered_session_expired", :unauthorized
      assert_no_difference "Doorkeeper::AccessToken.count" do
        post "/oauth/token", params: refresh_request(final)
        assert_token_error "remembered_session_expired"
      end
      assert_nil Mobile::RememberedSession.sole.revoked_at
    end
  end

  test "a lost initial response is recovered with the same code verifier and exchange identity" do
    travel_to Time.utc(2026, 10, 12, 20) do
      exchange = authorization_exchange
      post "/oauth/token", params: exchange
      assert_response :success
      first = response.parsed_body
      travel 60.seconds
      post "/oauth/token", params: exchange.merge(code_verifier: "x" * 64)
      assert_token_error "invalid_authorization_code"
      assert_nil Mobile::RememberedSession.sole.revoked_at
      assert_no_difference [ "Doorkeeper::AccessToken.count", "Mobile::RefreshCredential.count" ] do
        post "/oauth/token", params: exchange
        assert_response :success
      end
      assert_equal first["access_token"], response.parsed_body["access_token"]
      assert_equal first["refresh_token"], response.parsed_body["refresh_token"]
      assert_equal 840, response.parsed_body["expires_in"]
      assert_equal first["expires_at"], response.parsed_body["expires_at"]
    end
  end

  test "a restarted client recovers a lost rotation without minting another successor" do
    first = issue_credentials
    request = refresh_request(first)
    post "/oauth/token", params: request
    assert_response :success
    issued = response.parsed_body
    restarted = ActionDispatch::Integration::Session.new(Rails.application)
    assert_no_difference [ "Doorkeeper::AccessToken.count", "Mobile::RefreshCredential.count" ] do
      restarted.post "/oauth/token", params: request
      assert_equal 200, restarted.response.status
    end
    recovered = restarted.response.parsed_body
    assert_equal issued["access_token"], recovered["access_token"]
    assert_equal issued["refresh_token"], recovered["refresh_token"]
    restarted.get "/api/mobile/v1/session", headers: bearer(recovered)
    assert_equal 200, restarted.response.status
    assert_equal first["remembered_session_id"], restarted.response.parsed_body["remembered_session_id"]
    record = Mobile::TokenExchange.order(:id).last
    assert_not_includes record.response_ciphertext, issued["refresh_token"]
    assert_not_includes record.response_ciphertext, issued["access_token"]
    assert_not_equal issued["refresh_token"], record.issued_refresh_credential.token_digest
  end

  test "consumed credential reuse with a different request revokes all access tokens and renewal" do
    first = issue_credentials
    second = renew(first)
    assert_no_difference "Doorkeeper::AccessToken.count" do
      post "/oauth/token", params: refresh_request(first)
      assert_token_error "refresh_reuse_detected"
    end
    [ first, second ].each do |credentials|
      get "/api/mobile/v1/session", headers: bearer(credentials)
      assert_api_error "refresh_reuse_detected", :unauthorized
    end
    post "/oauth/token", params: refresh_request(second)
    assert_token_error "refresh_reuse_detected"
    assert_empty Mobile::TokenExchange.where.not(response_ciphertext: nil)
  end

  test "the recovery window never slides and ends at exactly 120 seconds" do
    travel_to Time.utc(2026, 10, 12, 20) do
      first = issue_credentials
      request = refresh_request(first)
      post "/oauth/token", params: request
      assert_response :success
      second = response.parsed_body
      travel 119.seconds
      post "/oauth/token", params: request
      assert_response :success
      assert_equal second["refresh_token"], response.parsed_body["refresh_token"]
      travel 1.second
      post "/oauth/token", params: request
      assert_token_error "refresh_reuse_detected"
      get "/api/mobile/v1/session", headers: bearer(second)
      assert_api_error "refresh_reuse_detected", :unauthorized
    end
  end

  test "an earlier exchange cannot recover after its successor has been renewed" do
    first = issue_credentials
    request = refresh_request(first)
    post "/oauth/token", params: request
    second = response.parsed_body
    third = renew(second)
    post "/oauth/token", params: request
    assert_token_error "refresh_reuse_detected"
    get "/api/mobile/v1/session", headers: bearer(third)
    assert_api_error "refresh_reuse_detected", :unauthorized
  end

  test "bad exchange identity client issuer and credential cannot rotate or revoke a connection" do
    first = issue_credentials
    request = refresh_request(first)
    assert_no_difference [ "Mobile::RefreshCredential.count", "Doorkeeper::AccessToken.count" ] do
      [ nil, "not-a-uuid", [] ].each do |bad|
        post "/oauth/token", params: request.merge(exchange_id: bad)
        assert_token_error "invalid_exchange_id"
      end
      post "/oauth/token", params: request.merge(refresh_token: "not-a-credential")
      assert_token_error "invalid_refresh_token"
      post "/oauth/token", params: request.merge(client_id: "different-client")
      assert_response :unauthorized
      assert_equal "invalid_client", response.parsed_body["error_code"]
      host! "different.example.com"
      post "/oauth/token", params: request
      assert_response :service_unavailable
      assert_equal "unavailable", response.parsed_body["error_code"]
    end
    assert_nil Mobile::RememberedSession.sole.revoked_at
    assert_nil Mobile::RefreshCredential.sole.consumed_at
  end

  test "website account disable immediately denies unexpired tokens and reenable never revives them" do
    first = issue_credentials
    legacy = mobile_headers
    @other.set_login_access_override!(disabled: true)
    get "/api/mobile/v1/session", headers: bearer(first)
    assert_api_error "account_unavailable", :unauthorized
    get "/api/mobile/v1/session", headers: legacy
    assert_api_error "account_unavailable", :unauthorized
    post "/oauth/token", params: refresh_request(first)
    assert_token_error "account_unavailable"
    @other.set_login_access_override!(disabled: false)
    get "/api/mobile/v1/session", headers: bearer(first)
    assert_api_error "revoked_session", :unauthorized
    get "/api/mobile/v1/session", headers: legacy
    assert_api_error "revoked_session", :unauthorized
    post "/oauth/token", params: refresh_request(first)
    assert_token_error "revoked_session"
  end

  test "roster removal enforces the same website and remembered account boundary" do
    first = issue_credentials
    @other.person.update!(roster_removed_at: Time.current)
    @other.apply_roster_access!
    assert @other.reload.disabled_at
    get "/api/mobile/v1/session", headers: bearer(first)
    assert_api_error "account_unavailable", :unauthorized
    post "/oauth/token", params: refresh_request(first)
    assert_token_error "account_unavailable"
  end

  test "export and temporary availability changes preserve the account while pilot loss denies access" do
    @other.permission_grants.create!(capability: "export_buddy_contacts")
    first = issue_credentials
    @other.permission_grants.where(capability: "export_buddy_contacts").destroy_all
    get "/api/mobile/v1/session", headers: bearer(first)
    assert_response :success
    assert_equal false, response.parsed_body.dig("capabilities", "contacts_export")
    get "/api/mobile/v1/people/#{@member.id}/contact-export", headers: bearer(first)
    assert_api_error "export_not_permitted", :forbidden
    ENV["MOBILE_BUDDY_CHECK_ENABLED"] = "false"
    post "/oauth/token", params: refresh_request(first)
    assert_response :service_unavailable
    assert_equal "unavailable", response.parsed_body["error_code"]
    assert_nil Mobile::RememberedSession.sole.revoked_at
    ENV["MOBILE_BUDDY_CHECK_ENABLED"] = "true"
    second = renew(first)
    @other.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    get "/api/mobile/v1/session", headers: bearer(second)
    assert_api_error "account_unavailable", :forbidden
    post "/oauth/token", params: refresh_request(second)
    assert_token_error "account_unavailable"
  end

  test "app logout accepts a consumed renewal credential and revokes the whole family" do
    first = issue_credentials
    second = renew(first)
    ENV["MOBILE_BUDDY_CHECK_ENABLED"] = "false"
    post "/oauth/revoke", params: { client_id: @mobile_client.uid, token: first["refresh_token"], token_type_hint: "refresh_token" }
    assert_response :success
    ENV["MOBILE_BUDDY_CHECK_ENABLED"] = "true"
    get "/api/mobile/v1/session", headers: bearer(second)
    assert_api_error "revoked_session", :unauthorized
    post "/oauth/token", params: refresh_request(second)
    assert_token_error "revoked_session"
    post "/oauth/revoke", params: { client_id: @mobile_client.uid, token: "unknown" }
    assert_response :success
  end

  test "website revocation shows the remembered connection after access expiry and enforces ownership" do
    first = issue_credentials
    travel 16.minutes do
      get mobile_sessions_path
      assert_response :success
      assert_select "form[action='#{mobile_remembered_session_path(first['remembered_session_id'])}']", count: 1
      sign_in_as(@volunteer)
      delete mobile_remembered_session_path(first["remembered_session_id"])
      assert_response :not_found
      assert_nil Mobile::RememberedSession.sole.revoked_at
      sign_in_as(@other)
      delete mobile_remembered_session_path(first["remembered_session_id"])
      assert_redirected_to mobile_sessions_path
      post "/oauth/token", params: refresh_request(first)
      assert_token_error "revoked_session"
    end
  end

  test "recovery cleanup removes expired encrypted responses without deleting sessions or credential digests" do
    travel_to Time.utc(2026, 10, 12, 20) do
      first = issue_credentials
      travel 119.seconds
      ExpireMobileTokenResponsesJob.perform_now
      assert Mobile::TokenExchange.sole.response_ciphertext
      travel 1.second
      assert_no_difference [ "Mobile::RememberedSession.count", "Mobile::RefreshCredential.count", "Mobile::TokenExchange.count" ] do
        ExpireMobileTokenResponsesJob.perform_now
      end
      assert_nil Mobile::TokenExchange.sole.response_ciphertext
      second = renew(first)
      get "/api/mobile/v1/session", headers: bearer(second)
      assert_response :success
    end
  end

  test "account disable also invalidates pending consent codes after the account is enabled again" do
    exchange = authorization_exchange
    @other.set_login_access_override!(disabled: true)
    @other.set_login_access_override!(disabled: false)
    assert_no_difference [ "Doorkeeper::AccessToken.count", "Mobile::RefreshCredential.count" ] do
      post "/oauth/token", params: exchange
      assert_token_error "revoked_session"
    end
  end

  test "remembered session revocation retains browser CSRF protection and secrets are filtered" do
    first = issue_credentials
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    delete mobile_remembered_session_path(first["remembered_session_id"])
    assert_response :unprocessable_entity
    assert_nil Mobile::RememberedSession.sole.revoked_at
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      .filter(refresh_request(first).merge(access_token: first["access_token"], code_verifier: @verifier))
    %i[refresh_token exchange_id access_token code_verifier].each { |field| assert_equal "[FILTERED]", filtered[field] }
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  private

  def issue_credentials
    post "/oauth/token", params: authorization_exchange
    assert_response :success
    response.parsed_body
  end

  def refresh_request(credentials)
    { grant_type: "refresh_token", client_id: @mobile_client.uid,
      refresh_token: credentials.fetch("refresh_token"), exchange_id: SecureRandom.uuid }
  end

  def renew(credentials)
    post "/oauth/token", params: refresh_request(credentials)
    assert_response :success
    response.parsed_body
  end

  def assert_token_error(code)
    assert_response :bad_request
    assert_equal code, response.parsed_body["error_code"]
  end

  def assert_api_error(code, status)
    assert_response status
    assert_equal code, response.parsed_body.dig("error", "code")
  end

  def authorization_exchange
    sign_in_as(@other)
    post "/oauth/authorize", params: @authorization
    assert_response :redirect
    code = URI.decode_www_form(URI.parse(response.location).query).to_h.fetch("code")
    { grant_type: "authorization_code", client_id: @mobile_client.uid, redirect_uri: @mobile_client.redirect_uri,
      code: code, code_verifier: @verifier, exchange_id: SecureRandom.uuid }
  end

  def bearer(credentials)
    { "Authorization" => "Bearer #{credentials.fetch('access_token')}" }
  end
end
