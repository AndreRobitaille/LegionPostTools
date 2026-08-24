require "test_helper"

class Loops::RosterSynchronizerTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :payloads

    def initialize(rejected_email: nil, terminal_error: nil)
      @rejected_email = rejected_email
      @terminal_error = terminal_error
      @payloads = []
    end

    def open
      raise @terminal_error if @terminal_error

      yield self
    end

    def update_contact(payload)
      @payloads << payload
      return unless payload[:email] == @rejected_email

      raise Loops::Client::RequestError.new("Provider rejected contact", status: 400)
    end
  end

  setup do
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

  test "continues after a contact rejection and records the member" do
    client = FakeClient.new(rejected_email: "ready@example.com")
    roster_sync = create_sync

    Loops::RosterSynchronizer.new(roster_sync, client: client, sleeper: ->(_) { }).call

    assert_equal "completed", roster_sync.reload.status
    assert_equal 0, roster_sync.synced_count
    assert_equal 1, roster_sync.failed_count
    assert_equal "M100", roster_sync.failures.first["member_number"]
    assert_equal "Provider rejected contact", roster_sync.failures.first["message"]
  end

  test "refuses to sync after a newer roster import" do
    roster_sync = create_sync
    RosterImport.create!(status: "completed", imported_at: 1.minute.from_now, uploaded_filename: "new.csv")

    Loops::RosterSynchronizer.new(roster_sync, client: FakeClient.new, sleeper: ->(_) { }).call

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

  def create_sync
    LoopsRosterSync.create!(roster_import: @roster_import, requested_by: @requester, eligible_count: 1)
  end
end
