class BuddyRememberedFixture
  NAME = "Synthetic Remembered Sign-in American Legion Post"
  ACTIONS = %w[expire_access disable reenable revoke].freeze

  def self.guard!
    raise "Dedicated synthetic database required" unless Rails.env.test? &&
      ActiveRecord::Base.connection_db_config.database == "legion_buddy_remembered_test" &&
      ENV["MOBILE_BUDDY_CHECK_ISSUER"] == "https://192.168.37.41:3446"
  end

  def self.setup!
    guard!
    raise "Empty database required; never reset a fixture" if Organization.exists? || Person.exists? || User.exists?
    fixture = ApplicationRecord.transaction do
      organization = Organization.create!(name: NAME, unit_type: "american_legion_post", timezone: "America/Chicago")
      Installation.singleton.update!(setup_completed_at: Time.current)
      caller = User.create!(person: Person.create!(first_name: "Jamie", last_name: "Caller"), email_address: "jamie@example.test")
      caller.permission_grants.create!(capability: "use_mobile_buddy_checks")
      caller.permission_grants.create!(capability: "export_buddy_contacts")
      steward = User.create!(person: Person.create!(first_name: "Pat", last_name: "Steward"), email_address: "pat@example.test")
      steward.permission_grants.create!(capability: "manage_settings")
      people = [ [ "Harper", "Draft" ], [ "Avery", "Neighbor" ], [ "Cameron", "Companion" ] ].each_with_index.to_h do |names, index|
        person = Person.create!(first_name: names.first, last_name: names.last, member_number: (index + 1).to_s.rjust(12, "0"),
          roster_member_status: "Active", roster_paid_through_year: Organization.current_local_date.year,
          roster_phone_number: "+1-202-555-03#{index.to_s.rjust(2, '0')}", roster_email_address: "#{names.first.downcase}@example.test",
          roster_imported_at: Time.current)
        [ names.first.downcase, person.id ]
      end
      client = Doorkeeper::Application.create!(name: "Synthetic remembered Buddy Checks", redirect_uri: "org.wipost165.buddychecks:/oauth/callback",
        scopes: "buddy_check", confidential: false)
      { organization_id: organization.id, caller_id: caller.id, steward_id: steward.id, people: people,
        issuer: ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER"), client_id: client.uid, callback: client.redirect_uri }
    end
    File.write(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE"), JSON.pretty_generate(fixture), perm: 0o600)
    path = File.join(File.dirname(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE")), "environment.json")
    configuration = JSON.parse(File.read(path)).merge("MOBILE_BUDDY_CHECK_CLIENT_ID" => fixture.fetch(:client_id))
    File.write(path, JSON.pretty_generate(configuration), perm: 0o600)
    fixture
  end

  def initialize
    self.class.guard!
    @fixture = JSON.parse(File.read(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE")))
    raise "Wrong synthetic installation" unless Organization.count == 1 && Organization.find(@fixture.fetch("organization_id")).name == NAME
    @caller = User.find(@fixture.fetch("caller_id"))
    raise "Wrong synthetic caller" unless @caller.email_address == "jamie@example.test"
  end

  def status
    { database: ActiveRecord::Base.connection_db_config.database, fixture: @fixture,
      caller_enabled: @caller.reload.disabled_at.nil?, contacts: MembershipContact.count, operations: BuddyOperation.count,
      families: Mobile::RememberedSession.where(user: @caller).order(:id).map { |row| row.attributes.slice("id", "public_id", "authorized_at", "expires_at", "revoked_at", "revocation_reason") },
      access: Doorkeeper::AccessToken.where(resource_owner_id: @caller.id).order(:id).map { |row| row.attributes.slice("id", "remembered_session_id", "created_at", "expires_in", "revoked_at") },
      refresh_count: Mobile::RefreshCredential.count, exchange_count: Mobile::TokenExchange.count }
  end

  def advance!(action, checkpoint:)
    raise "Known action and observed checkpoint required" unless ACTIONS.include?(action) && checkpoint.to_s.strip.length.between?(8, 500)
    directory = File.dirname(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE"))
    File.open(File.join(directory, "control.lock"), File::RDWR | File::CREAT, 0o600) do |lock|
      lock.flock(File::LOCK_EX)
      before = status
      @caller.with_lock do
        case action
        when "expire_access"
          tokens = Doorkeeper::AccessToken.where(resource_owner_id: @caller.id, revoked_at: nil)
          raise "Sign in before expiring access" if tokens.empty?
          tokens.update_all(created_at: 16.minutes.ago)
        when "disable", "reenable"
          disabled = action == "disable"
          raise "Already in requested access state" if @caller.disabled_at.present? == disabled
          @caller.set_login_access_override!(disabled: disabled)
        when "revoke"
          Mobile::RememberedSession.where(user: @caller, revoked_at: nil).find_each(&:revoke!)
        end
      end
      after = status
      File.open(File.join(directory, "checkpoints.jsonl"), "a", 0o600) do |file|
        file.puts(JSON.generate(at: Time.current.iso8601(6), action: action, checkpoint: checkpoint, before: before, after: after))
        file.flush
        file.fsync
      end
      after
    end
  end
end

case ARGV.shift
when "setup"
  puts JSON.pretty_generate(BuddyRememberedFixture.setup!)
when "status"
  puts JSON.pretty_generate(BuddyRememberedFixture.new.status)
when "advance"
  action, checkpoint = ARGV
  puts JSON.pretty_generate(BuddyRememberedFixture.new.advance!(action, checkpoint: checkpoint))
else
  abort "Use the guarded buddy_remembered.rb entry point."
end
