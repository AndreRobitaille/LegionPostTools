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

  private

  def roster_source_state
    [ Person.order(:id).map(&:attributes), User.order(:id).map(&:attributes), RosterImport.order(:id).map(&:attributes) ]
  end

  def create_sync
    LoopsRosterSync.create!(roster_import: @roster_import, requested_by: @requester, eligible_count: 1)
  end
end
