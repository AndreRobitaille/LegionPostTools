require "test_helper"
require "timeout"

class LastAdministratorConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @organization = Organization.create!(name: "Synthetic concurrency Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @installation = Installation.singleton
    @original_setup_completed_at = @installation.setup_completed_at
    @installation.update!(setup_completed_at: Time.current)
    @users = 2.times.map do |index|
      person = Person.create!(first_name: "Concurrent", last_name: "Administrator #{index}")
      user = User.create!(person: person, email_address: "admin-#{SecureRandom.hex(8)}@example.test")
      %w[manage_settings manage_people].each { |capability| user.permission_grants.create!(capability: capability) }
      user
    end
    @clients = @users.map do |user|
      client = ActionDispatch::Integration::Session.new(Rails.application)
      link = MagicLink.create_for!(user)
      client.post magic_link_session_path, params: { token: link.token }
      assert_equal 302, client.response.status
      client.get new_admin_roster_import_path
      assert_equal 200, client.response.status
      client
    end
  end

  teardown do
    @users&.each { |user| user.person.destroy! }
    @organization&.destroy!
    @installation&.update!(setup_completed_at: @original_setup_completed_at)
  end

  test "overlapping administrator grant removals preserve one enabled administrator" do
    assert_overlapping_changes_preserve_administration(:grant)
  end

  test "grant removal and manual disable preserve one enabled administrator" do
    assert_overlapping_changes_preserve_administration(:manual_disable)
  end

  test "grant removal and roster control preserve one enabled administrator" do
    @users.last.person.update!(member_number: "11200001", roster_member_status: "Expired")
    @users.last.update!(login_access_override: true, login_access_override_at: Time.current)
    assert_overlapping_changes_preserve_administration(:roster_control)
  end

  private

  def assert_overlapping_changes_preserve_administration(second_operation)
    identities = @users.map { |user| user.reload.attributes.slice("id", "person_id", "email_address", "email_verified_at", "webauthn_id") }
    people = @users.map { |user| user.person.reload.attributes }
    unrelated_grants = PermissionGrant.where(user: @users, capability: "manage_people").order(:id).map(&:attributes)
    session_identities = Session.where(user: @users).order(:id).pluck(:id, :user_id, :authenticated_at)
    threads = []

    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.transaction do
        blocker_pid = connection.select_value("SELECT pg_backend_pid()")
        @users.first.permission_grants.find_by!(capability: "manage_settings").lock!
        first, first_pid = start_operation(@clients.first, @users.first, :grant)
        threads << first
        await_database_state { blocking_pids(connection, first_pid).include?(blocker_pid) }
        second, second_pid = start_operation(@clients.last, @users.last, second_operation)
        threads << second
        assert_equal 3, [ blocker_pid, first_pid, second_pid ].uniq.size, "Observer and requests must use independent PostgreSQL connections"
        await_database_state do
          !second.alive? || (blocking_pids(connection, second_pid) & [ blocker_pid, first_pid ]).any?
        end
      end # Releasing this real grant-row lock allows both actual requests to finish.
    end
    threads.each { |thread| assert thread.join(20), "Administrator request did not finish after the row lock was released" }
    results = threads.map(&:value)

    enabled_admin_ids = User.where(disabled_at: nil).joins(:permission_grants)
      .where(permission_grants: { capability: "manage_settings" }).order(:id).pluck(:id)
    assert_equal 1, enabled_admin_ids.size, "Overlapping changes must preserve an enabled settings administrator"
    assert_equal identities, @users.map { |user| user.reload.attributes.slice("id", "person_id", "email_address", "email_verified_at", "webauthn_id") }
    assert_equal people, @users.map { |user| user.person.reload.attributes }
    assert_equal unrelated_grants, PermissionGrant.where(user: @users, capability: "manage_people").order(:id).map(&:attributes)
    assert_equal session_identities, Session.where(user: @users).order(:id).pluck(:id, :user_id, :authenticated_at)
    assert_equal [ 302, 302 ], results.map { |result| result.fetch(:status) }
    assert_equal @users.map { |user| person_url(user.person, host: "www.example.com") }, results.map { |result| result.fetch(:location) }

    @clients.each(&:follow_redirect!)
    bodies = @clients.map { |client| Nokogiri::HTML(client.response.body).text }
    assert_equal 1, bodies.count { |body| body.include?("At least one enabled administrator account is required.") }
    accepted_messages = [ "Permissions updated." ]
    accepted_messages << "Sign-in is off. Roster imports will leave it off until an administrator enables it again." if second_operation == :manual_disable
    accepted_messages << "Sign-in now follows the National roster and is off because the current status is not eligible." if second_operation == :roster_control
    assert_equal 1, bodies.count { |body| accepted_messages.any? { |message| body.include?(message) } }
    @clients.zip(@users).each do |client, user|
      client.get new_admin_roster_import_path
      if enabled_admin_ids.include?(user.id)
        assert_equal 200, client.response.status
        assert_includes Nokogiri::HTML(client.response.body).css("h1").text, "Import roster"
      else
        assert_equal 302, client.response.status
        assert_not_includes client.response.body, "Upload and import"
      end
    end
  ensure
    threads&.each do |thread|
      raise "Administrator request remained active during cleanup" unless thread.join(20)
    end
  end

  def start_operation(client, user, operation)
    ready = Queue.new
    thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET statement_timeout = '15s'")
        ready << connection.select_value("SELECT pg_backend_pid()")
        case operation
        when :grant
          client.patch admin_user_permission_grants_path(user), params: { permission_grant: { capabilities: [ "manage_people" ] } }
        when :manual_disable
          client.delete admin_person_user_account_path(user.person)
        when :roster_control
          client.patch roster_control_admin_person_user_account_path(user.person)
        end
        { status: client.response.status, location: client.response.location }
      ensure
        connection.execute("SET statement_timeout = DEFAULT")
      end
    end
    [ thread, Timeout.timeout(10) { ready.pop } ]
  end

  def blocking_pids(connection, pid)
    connection.uncached { connection.select_values("SELECT unnest(pg_blocking_pids(#{Integer(pid)}))") }
  end

  def await_database_state
    Timeout.timeout(10) do
      sleep 0.01 until yield
    end
  end
end
