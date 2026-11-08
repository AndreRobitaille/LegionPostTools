require "test_helper"
require_relative "../../support/minutes_distribution_provider"

class Loops::RosterSynchronizerTest < ActiveSupport::TestCase
  class FakeClient < MinutesDistributionProvider
    def initialize(rejected_email: nil, terminal_error: nil)
      super()
      self.rejected_email = rejected_email
      self.terminal_error = terminal_error
    end
  end

  setup do
    organization = Organization.create!(name: "Synthetic roster Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    organization.create_minutes_distribution_setting!(post_members_list_id: "members", minutes_recipients_list_id: "minutes")
    @person = Person.create!(
      first_name: "Ready", last_name: "Member", member_number: "M100",
      roster_member_status: "active", roster_email_address: "ready@example.com"
    )
    requester_person = Person.create!(first_name: "Admin", last_name: "Officer")
    @requester = User.create!(person: requester_person, email_address: "admin@example.com")
    @roster_import = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "roster.csv")
  end

  test "completes an upsert run and records progress" do
    client = FakeClient.new
    roster_sync = create_sync

    Loops::RosterSynchronizer.new(roster_sync, client: client, sleeper: ->(_) { }).call

    assert_equal "completed", roster_sync.reload.status
    assert_equal 1, roster_sync.synced_count
    assert_equal 0, roster_sync.failed_count
    assert_equal "ready@example.com", client.payloads.first[:email]
    assert_not client.payloads.first.key?(:subscribed)
  end

  test "records a rejected contact without aborting the run" do
    client = FakeClient.new(rejected_email: "ready@example.com")
    roster_sync = create_sync

    Loops::RosterSynchronizer.new(roster_sync, client: client, sleeper: ->(_) { }).call

    assert_equal "completed", roster_sync.reload.status
    assert_equal 0, roster_sync.synced_count
    assert_equal 1, roster_sync.failed_count
    assert_equal "M100", roster_sync.failures.first["member_number"]
    assert_equal "Provider rejected contact", roster_sync.failures.first["message"]
  end

  test "a later contact is actually sent after the first contact is rejected" do
    Person.create!(first_name: "Later", last_name: "Zzz", member_number: "M200",
      roster_member_status: "active", roster_email_address: "later@example.test")
    freeze_time do
      roster_sync = create_sync
      original_source = roster_source_state
      client = FakeClient.new(rejected_email: "ready@example.com")
      intervals = []

      Loops::RosterSynchronizer.new(roster_sync, client: client, sleeper: ->(interval) { intervals << interval }).call

      assert_equal [
        { email: "ready@example.com", userId: "american-legion-member:M100", firstName: "Ready", lastName: "Member", mailingLists: { "members" => true } },
        { email: "later@example.test", userId: "american-legion-member:M200", firstName: "Later", lastName: "Zzz", mailingLists: { "members" => true } }
      ], client.payloads
      assert_equal 1, client.open_count
      assert_equal original_source, roster_source_state
      assert_equal @roster_import.id, roster_sync.reload.roster_import_id
      assert_equal @requester.id, roster_sync.requested_by_id
      assert_equal [ 2, 1, 1 ], [ roster_sync.eligible_count, roster_sync.synced_count, roster_sync.failed_count ]
      assert_equal [ { "name" => "Ready Member", "member_number" => "M100", "email" => "ready@example.com",
        "message" => "Provider rejected contact", "status" => 400 } ], roster_sync.failures
      assert_equal Time.current, roster_sync.started_at
      assert_equal Time.current, roster_sync.finished_at
      assert_equal 1, intervals.size
      assert_operator intervals.sole, :>, 0
      assert_equal "completed", roster_sync.status
    end
  end

  test "refuses to sync after a newer roster import" do
    roster_sync = create_sync
    RosterImport.create!(status: "completed", imported_at: 1.minute.from_now, uploaded_filename: "new.csv")

    client = FakeClient.new
    original_source = roster_source_state
    original_identity = roster_sync.attributes.slice("id", "roster_import_id", "requested_by_id")

    Loops::RosterSynchronizer.new(roster_sync, client: client, sleeper: ->(_) { }).call

    assert_equal 0, client.open_count, "Superseded source must be refused before opening the provider client"
    assert_equal [], client.payloads
    assert_equal original_source, roster_source_state
    assert_equal original_identity, roster_sync.reload.attributes.slice("id", "roster_import_id", "requested_by_id")
    assert_nil roster_sync.started_at
    assert_equal [ 0, 0 ], [ roster_sync.synced_count, roster_sync.failed_count ]
    assert_equal "failed", roster_sync.reload.status
    assert_match(/newer roster import/, roster_sync.error_message)
  end

  test "marks a terminal connection failure" do
    roster_sync = create_sync
    error = Loops::Client::NetworkError.new("Loops connection failed (Timeout::Error).")

    Loops::RosterSynchronizer.new(roster_sync, client: FakeClient.new(terminal_error: error), sleeper: ->(_) { }).call

    assert_equal "failed", roster_sync.reload.status
    assert_equal "Loops connection failed (Timeout::Error).", roster_sync.error_message
  end

  test "marks missing job-time configuration as a failed sync" do
    roster_sync = create_sync
    original = ENV.delete("LOOPS_API_KEY")

    Loops::RosterSynchronizer.new(roster_sync, sleeper: ->(_) { }).call

    assert_equal "failed", roster_sync.reload.status
    assert_match(/LOOPS_API_KEY/, roster_sync.error_message)
  ensure
    ENV["LOOPS_API_KEY"] = original if original
  end

  test "changed roster email keeps the same contact choices and managed provenance through rerun and removal" do
    client = FakeClient.new
    client.add(@person.roster_email_address, mailingLists: { "minutes" => true, "officers" => true })
    assert_equal 0, run_sync(client).failed_count
    client.contacts.fetch(@person.roster_email_address)["subscribed"] = false
    original = client.contacts.fetch(@person.roster_email_address).deep_dup
    old_record = Organization.first!.loops_roster_enrollments.sole
    @person.update!(roster_email_address: "changed@example.test")

    sync = run_sync(client)

    assert_equal [ "completed", 1, 0 ], [ sync.status, sync.synced_count, sync.failed_count ]
    assert_equal 1, sync.list_results.fetch("email_addresses_updated")
    assert_equal original.merge("email" => "changed@example.test"), client.contacts.fetch("changed@example.test")
    assert_not client.contacts.key?("ready@example.com")
    assert_not old_record.reload.active
    current_record = Organization.first!.loops_roster_enrollments.find_by!(email: "changed@example.test")
    assert_equal [ original.fetch("id"), "american-legion-member:M100", true ],
      [ current_record.loops_contact_id, current_record.member_user_id, current_record.active ]
    assert_equal 0, run_sync(client).failed_count, "An ordinary rerun must not keep reporting the previous address"

    @person.update!(roster_removed_at: Time.current)
    removed = run_sync(client)
    assert_equal 0, removed.failed_count
    assert_equal 1, removed.list_results.fetch("removed")
    assert_equal({ "minutes" => true, "officers" => true }, client.contacts.fetch("changed@example.test").fetch("mailingLists"))
    assert_not current_record.reload.active
    assert_equal false, client.contacts.fetch("changed@example.test").fetch("subscribed")
  end

  test "changed email preserves a Post members list opt-out on the existing contact" do
    client = FakeClient.new
    client.add(@person.roster_email_address)
    client.list_opt_outs << [ @person.roster_email_address, "members" ]
    run_sync(client)
    id = client.contacts.fetch(@person.roster_email_address).fetch("id")
    @person.update!(roster_email_address: "opted-out-new@example.test")

    sync = run_sync(client)
    assert_equal 0, sync.failed_count
    assert_equal 1, sync.list_results.fetch("retained_opt_outs")
    assert_equal id, client.contacts.fetch(@person.roster_email_address).fetch("id")
    assert_empty client.contacts.fetch(@person.roster_email_address).fetch("mailingLists")
    assert_equal 0, run_sync(client).failed_count
    assert_empty client.contacts.fetch(@person.roster_email_address).fetch("mailingLists")
  end

  test "changed email never merges with another contact even when its member identity is blank" do
    client = FakeClient.new
    run_sync(client)
    client.add("occupied@example.test", mailingLists: { "minutes" => true })
    before = client.contacts.deep_dup
    client.payloads.clear
    @person.update!(roster_email_address: "occupied@example.test")

    sync = run_sync(client)
    assert_equal 1, sync.list_results.fetch("identity_conflicts")
    assert_equal before, client.contacts
    assert_empty client.payloads
    assert Organization.first!.loops_roster_enrollments.find_by!(email: "ready@example.com").active
  end

  test "retry recovers enrollment after Loops accepted an email update but the confirmation read failed" do
    client = FakeClient.new
    run_sync(client)
    old_record = Organization.first!.loops_roster_enrollments.sole
    @person.update!(roster_email_address: "recovered@example.test")
    client.define_singleton_method(:find_contact) do |email: nil, user_id: nil|
      if email == "recovered@example.test" && contacts.key?(email)
        raise Loops::Client::NetworkError, "Synthetic read interrupted after update"
      end
      super(email: email, user_id: user_id)
    end

    assert_equal "failed", run_sync(client).status
    assert client.contacts.key?("recovered@example.test"), "Provider accepted the update before interruption"
    assert old_record.reload.active
    client.singleton_class.remove_method(:find_contact)

    recovered = run_sync(client)
    assert_equal [ "completed", 0 ], [ recovered.status, recovered.failed_count ]
    assert_not old_record.reload.active
    assert Organization.first!.loops_roster_enrollments.find_by!(email: "recovered@example.test").active
    @person.update!(roster_removed_at: Time.current)
    assert_equal 1, run_sync(client).list_results.fetch("removed")
  end

  test "departures and deceased members are globally unsubscribed even without prior managed enrollment" do
    client = FakeClient.new
    departing = Person.create!(first_name: "Former", last_name: "Member", member_number: "DEPARTED",
      roster_removed_at: Time.current, roster_member_status: "Active", roster_email_address: "old-former@example.test")
    deceased = Person.create!(first_name: "Deceased", last_name: "Member", member_number: "DECEASED",
      roster_member_status: " Deceased ", roster_email_address: "deceased@example.test")
    client.add("latest-former@example.test", userId: "american-legion-member:DEPARTED",
      mailingLists: { "members" => true, "minutes" => true, "officers" => true })
    client.add(deceased.roster_email_address, mailingLists: { "members" => true, "minutes" => true })
    client.add("outside@example.test", mailingLists: { "minutes" => true })
    untouched = client.contacts.fetch("outside@example.test").deep_dup

    sync = run_sync(client)

    assert_equal 0, sync.failed_count
    assert_equal 2, sync.list_results.fetch("globally_unsubscribed")
    assert_equal 2, sync.list_results.fetch("removed")
    assert_equal false, client.contacts.fetch("latest-former@example.test").fetch("subscribed")
    assert_equal({ "minutes" => true, "officers" => true }, client.contacts.fetch("latest-former@example.test").fetch("mailingLists"))
    assert_equal false, client.contacts.fetch(deceased.roster_email_address).fetch("subscribed")
    assert_equal untouched, client.contacts.fetch("outside@example.test")
    assert_equal 0, run_sync(client).failed_count

    departing.update!(roster_removed_at: nil, roster_email_address: "latest-former@example.test")
    returning = run_sync(client)
    assert_equal 0, returning.failed_count
    assert_equal 1, returning.list_results.fetch("retained_opt_outs")
    assert_equal false, client.contacts.fetch("latest-former@example.test").fetch("subscribed")
  end

  test "departure does not unsubscribe a contact assigned to another member or a shared address" do
    client = FakeClient.new
    Person.create!(first_name: "Former", last_name: "Conflicted", member_number: "DEPARTED",
      roster_removed_at: Time.current, roster_email_address: @person.roster_email_address)
    client.add(@person.roster_email_address, userId: "american-legion-member:M100", mailingLists: { "members" => true })

    sync = run_sync(client)

    assert_equal 1, sync.failed_count
    assert_equal 1, sync.list_results.fetch("removal_needs_review")
    assert_equal true, client.contacts.fetch(@person.roster_email_address).fetch("subscribed")
    assert_not client.payloads.any? { |payload| payload[:subscribed] == false }
  end

  test "interrupted global unsubscribe recovers on retry and retires enrollment only after confirmation" do
    client = FakeClient.new
    run_sync(client)
    enrollment = Organization.first!.loops_roster_enrollments.sole
    @person.update!(roster_member_status: "Deceased")
    client.define_singleton_method(:find_contact) do |email: nil, user_id: nil|
      if email && contacts.dig(email, "subscribed") == false
        raise Loops::Client::NetworkError, "Synthetic unsubscribe confirmation interrupted"
      end
      super(email: email, user_id: user_id)
    end

    assert_equal "failed", run_sync(client).status
    assert enrollment.reload.active
    assert_equal false, client.contacts.fetch(@person.roster_email_address).fetch("subscribed")
    client.singleton_class.remove_method(:find_contact)

    recovered = run_sync(client)
    assert_equal [ "completed", 0 ], [ recovered.status, recovered.failed_count ]
    assert_not enrollment.reload.active
    assert_equal false, client.contacts.fetch(@person.roster_email_address).fetch("subscribed")
  end

  private

  def run_sync(client)
    sync = create_sync
    Loops::RosterSynchronizer.new(sync, client: client, sleeper: ->(_) { }).call
    sync.reload
  end

  def roster_source_state
    [ Person.order(:id).map(&:attributes), User.order(:id).map(&:attributes), RosterImport.order(:id).map(&:attributes) ]
  end

  def create_sync
    LoopsRosterSync.create!(roster_import: @roster_import, requested_by: @requester, eligible_count: 1)
  end
end
