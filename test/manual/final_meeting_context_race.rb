raise "Synthetic test database required" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "legion_context_race_test"
organization = Organization.create!(name: "Synthetic race Post", unit_type: "american_legion_post", timezone: "America/Chicago")
body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
officer = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Adjutant"), email_address: "race-officer@example.com", email_verified_at: Time.current)
%w[attest_minutes record_minutes_approval].each { |capability| officer.permission_grants.create!(capability:) }
meeting = organization.meetings.create!(meeting_body: body, starts_at: 2.weeks.ago, title: "Recorded occurrence", location_name: "Recorded Hall")
approving = organization.meetings.create!(meeting_body: body, starts_at: 1.week.ago, title: "Later meeting", location_name: "Recorded Hall")
minutes = MeetingMinutes.create_from_meeting!(meeting:)
confirm = OfficialActionConfirmation.record_external!(minutes:, user: officer, action: "attest", evidence_note: "Synthetic race test.")
minutes.attest_with_confirmation!(confirmation: confirm)
original_meeting = meeting.reload.attributes
original_revision = minutes.member_revision.attributes
ready = Queue.new
release = Queue.new
pid = Queue.new
finalizer = Thread.new do
  ActiveRecord::Base.connection_pool.with_connection do
    MeetingMinutes.transaction do
      record = MeetingMinutes.find(minutes.id)
      confirmation = OfficialActionConfirmation.record_external!(minutes: record, user: officer, action: "record_membership_approval",
        action_payload: { approving_meeting_id: approving.id, disposition: "approved_as_presented" }, evidence_note: "Synthetic race test.")
      record.record_membership_approval_with_confirmation!(confirmation:)
      ready << true
      raise "Race release timed out" unless release.pop(timeout: 15)
    end
  end
end
updater = nil
begin
  raise "Finalization did not reach its uncommitted final state" unless ready.pop(timeout: 15)
  updater = Thread.new do
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute("SET lock_timeout = '15s'")
      pid << connection.select_value("SELECT pg_backend_pid()")
      record = Meeting.find(meeting.id)
      [ record.update_with_agenda_sync(title: "Concurrent historical rewrite"), record.errors.full_messages ]
    end
  end
  backend_pid = pid.pop(timeout: 15) || raise("Updater did not start")
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
  waiting = false
  until Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    waiting = ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value("SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(backend_pid)}") } == "Lock"
    break if waiting || !updater.alive?
    sleep 0.01
  end
  raise "Expected the occurrence update to wait for finalization's parent-row lock" unless waiting
ensure
  release << true
  raise "Finalizer did not finish" unless finalizer.join(20)
  raise "Updater did not finish" if updater && !updater.join(20)
end
finalizer.value
result = updater.value
raise "Concurrent update did not receive the specific controlled refusal: #{result.inspect}" unless result == [ false, [ Meeting::FINAL_CONTEXT_ERROR ] ]
raise "Occurrence changed" unless meeting.reload.attributes == original_meeting
raise "Signed revision changed" unless minutes.member_revision.reload.attributes == original_revision
raise "Final approval missing" unless minutes.reload.membership_approved? && minutes.membership_approval.approving_meeting_id == approving.id
puts "PASS: actual finalization held the parent-row lock; waiting update returned the specific refusal; occurrence, revision and approval preserved."
