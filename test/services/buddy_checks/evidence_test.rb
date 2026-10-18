require "test_helper"
require_relative "../../support/buddy_checks_helpers"

class BuddyChecksEvidenceTest < ActiveSupport::TestCase
  include BuddyChecksHelpers
  setup { setup_buddy_checks }
  teardown { restore_buddy_configuration }

  test "unknown history never means never contacted and old evidence ranks deterministically" do
    suggestions = BuddyChecks::Suggestions.new(mobile_access)
    assert_equal "insufficient_history", suggestions.suggest[:state]
    assert_equal "unknown", suggestions.coverage[:missing_history]
    operations.record(**buddy_payload(facts: buddy_facts(occurred_at: 100.days.ago.iso8601)))
    suggestions = BuddyChecks::Suggestions.new(mobile_access)
    assert_equal @member.id, suggestions.suggest.dig(:person, :id)
    assert_equal "recorded_contact_is_older", suggestions.suggest[:reason]
    operations.snooze(operation_id: SecureRandom.uuid, person_id: @member.id, until_at: 1.day.from_now.iso8601)
    assert_equal "insufficient_history", suggestions.suggest[:state]
    assert_equal @member.id, BuddyChecks::Suggestions.new(mobile_access(@volunteer)).suggest.dig(:person, :id)
  end

  test "other caller attempts conversations assignments and open work exclude without exposing details" do
    @drive.update!(purpose: "buddy_check")
    assert_equal "assigned_elsewhere", BuddyChecks::Suggestions.new(mobile_access).eligibility(@member)[:reason]
    @assignment.update!(revoked_at: Time.current)
    receipt = operations(@volunteer).record(**buddy_payload(facts: buddy_facts(outcome: "wrong_number")))
    assert_equal "recent_attempt", BuddyChecks::Suggestions.new(mobile_access).eligibility(@member)[:reason]
    operations(@volunteer).correct(operation_id: SecureRandom.uuid, id: receipt.dig("contact", "id"), expected_revision: 1,
      facts: buddy_facts(outcome: "not_attempted"))
    assert BuddyChecks::Suggestions.new(mobile_access).eligibility(@member)[:eligible]
    operations(@volunteer).record(**buddy_payload(facts: buddy_facts(occurred_at: 30.days.ago.iso8601)))
    assert_equal "recent_conversation", BuddyChecks::Suggestions.new(mobile_access).eligibility(@member)[:reason]
    operations(@volunteer).schedule(operation_id: SecureRandom.uuid, person_id: @member.id, due_at: 1.day.from_now.iso8601, entry_zone: "America/Chicago")
    assert_equal "open_follow_up", BuddyChecks::Suggestions.new(mobile_access).eligibility(@member)[:reason]
  end

  test "an agreed due callback can be prepared by its caller even inside recent-contact intervals" do
    operations.record(**buddy_payload(follow_up: { due_at: 1.hour.from_now.iso8601, entry_zone: "America/Chicago" }))
    travel 2.hours do
      assert BuddyChecks::Suggestions.new(mobile_access).eligibility(@member)[:eligible]
      assert_equal "open_follow_up", BuddyChecks::Suggestions.new(mobile_access(@volunteer)).eligibility(@member)[:reason]
    end
  end

  test "legacy date callbacks exclude other callers across years without inventing a due instant" do
    original = workspace.record_contact!(contact_attributes(membership_assignment_id: nil, purpose: "buddy_check",
      occurred_on: Organization.current_local_date - 14, outcome: "callback_requested", follow_up_on: Organization.current_local_date + 5))
    assert_equal "open_follow_up", BuddyChecks::Suggestions.new(mobile_access).eligibility(@member)[:reason]
    corrected = operations(@officer).correct(operation_id: SecureRandom.uuid, id: original.id, expected_revision: 1,
      facts: { channel: "phone", outcome: "no_answer", occurred_on: Organization.current_local_date.iso8601 })
    assert_equal original.follow_up_on.iso8601, corrected.dig("contact", "legacy_follow_up_on")
    assert_equal "callback_requested", original.reload.outcome
    travel 6.days do
      assert BuddyChecks::Suggestions.new(mobile_access(@officer)).eligibility(@member)[:eligible]
      assert_equal "open_follow_up", BuddyChecks::Suggestions.new(mobile_access).eligibility(@member)[:reason]
    end
  end

  test "legacy contacts retain honest precision and correction changes the year-independent workspace projection" do
    @drive.update!(purpose: "buddy_check")
    original = workspace.record_contact!(contact_attributes(occurred_on: Date.new(2025, 12, 30), notes: "Observed date only"))
    assert_nil operations(@volunteer).contact_payload(original)[:occurred_at]
    assert_equal "date", operations(@volunteer).contact_payload(original)[:precision]
    receipt = operations(@volunteer).correct(operation_id: SecureRandom.uuid, id: original.id, expected_revision: 1,
      facts: { channel: "phone", outcome: "no_answer", occurred_on: "2025-12-30" })
    assert_equal "date", receipt.dig("contact", "precision")
    assert_nil receipt.dig("contact", "occurred_at")
    assert_equal "Try contacting again", workspace(@volunteer).contact_work_item(@member, purpose: "buddy_check", assignment: @assignment)[:next_step]
    assert_equal "reached", original.reload.outcome
    assert_not original.update(outcome: "wrong_number")
  end

  test "unassigned event year derives from Post zone not entry zone or submission year" do
    receipt = operations.record(**buddy_payload(facts: buddy_facts(occurred_at: "2026-01-01T01:00:00Z", entry_zone: "Asia/Tokyo")))
    assert_equal 2025, receipt.dig("contact", "membership_year")
    assert_equal "2025-12-31", receipt.dig("contact", "occurred_on")
    assert_equal "Asia/Tokyo", receipt.dig("contact", "entry_zone")
  end

  test "complete general-member registers require explicit coverage and latest revisions control absence evidence" do
    first = buddy_meeting(days_ago: 20)
    second = buddy_meeting(days_ago: 5)
    entries = { @member.id.to_s => "absent", @unassigned.id.to_s => "not_recorded" }
    assert_raises(ActiveRecord::RecordInvalid) do
      BuddyAttendanceRegister.record!(meeting: first, user: @officer, expected_revision: 0, entries:, complete: true, coverage_note: "Reviewed synthetic attendance")
    end
    [ first, second ].each do |meeting|
      BuddyAttendanceRegister.record!(meeting:, user: @officer, expected_revision: 0, entries: entries.merge(@unassigned.id.to_s => "present"), complete: true, coverage_note: "Reviewed synthetic attendance")
    end
    suggestions = BuddyChecks::Suggestions.new(mobile_access)
    assert_equal 2, suggestions.absence_evidence(@member).size
    assert_empty suggestions.absence_evidence(@unassigned)
    assert_equal "two_recorded_absences", suggestions.suggest[:reason]
    BuddyAttendanceRegister.record!(meeting: second, user: @officer, expected_revision: 1, entries:, complete: false, coverage_note: "Review reopened: attendance uncertain")
    assert_empty suggestions.absence_evidence(@member)
    assert_equal 3, BuddyAttendanceRegister.count
    assert_equal 0, MeetingMinutes.count
    assert_not first.empty_record?
    assert_raises(BuddyChecks::Conflict) do
      BuddyAttendanceRegister.record!(meeting: second, user: @officer, expected_revision: 1, entries:, complete: false, coverage_note: "Stale review")
    end
    assert_raises(BuddyChecks::Denied) do
      BuddyAttendanceRegister.record!(meeting: first, user: @other, expected_revision: 1, entries:, complete: false, coverage_note: "Unauthorized review")
    end
  end

  test "attendance review leaves accepted minutes and their immutable revision unchanged" do
    meeting = buddy_meeting(days_ago: 20)
    approving = buddy_meeting(days_ago: 5)
    %w[attest_minutes record_minutes_approval].each { |capability| @officer.permission_grants.create!(capability:) }
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    confirmation = OfficialActionConfirmation.record_external!(minutes:, user: @officer, action: "attest", evidence_note: "Synthetic approval test.")
    minutes.attest_with_confirmation!(confirmation:)
    confirmation = OfficialActionConfirmation.record_external!(minutes:, user: @officer, action: "record_membership_approval",
      action_payload: { approving_meeting_id: approving.id, disposition: "approved_as_presented" }, evidence_note: "Synthetic approval test.")
    minutes.record_membership_approval_with_confirmation!(confirmation:)
    before_minutes = minutes.reload.attributes
    before_revision = minutes.member_revision.attributes
    before_meeting = meeting.reload.attributes
    BuddyAttendanceRegister.record!(meeting:, user: @officer, expected_revision: 0,
      entries: { @member.id.to_s => "absent", @unassigned.id.to_s => "present" }, complete: true, coverage_note: "Separate synthetic general-member attendance.")
    assert_equal before_minutes, minutes.reload.attributes
    assert_equal before_revision, minutes.member_revision.attributes
    assert_equal before_meeting, meeting.reload.attributes
    assert minutes.membership_approved?
  end

  test "receipt replay rechecks purpose pause and operation keys are scoped to user" do
    payload = buddy_payload
    receipt = operations.record(**payload)
    operations(@volunteer).record(**payload)
    assert_equal 2, MembershipContact.count
    @drive.update!(purpose: "buddy_check")
    workspace.record_contact!(contact_attributes(outcome: "do_not_contact"))
    assert_raises(BuddyChecks::Denied) { operations.receipt(receipt["operation_id"]) }
    assert_raises(BuddyChecks::Denied) { operations.record(**payload) }
    assert_equal 2, BuddyOperation.count
  end

  test "same-day offline entries use event instants rather than arrival order" do
    travel_to Time.current.change(hour: 20, min: 0, sec: 0) do
      @drive.update!(purpose: "buddy_check")
      operations(@volunteer).record(**buddy_payload(assignment_id: @assignment.id, facts: buddy_facts(occurred_at: 2.hours.ago.iso8601)))
      operations(@volunteer).record(**buddy_payload(assignment_id: @assignment.id, facts: buddy_facts(occurred_at: 3.hours.ago.iso8601, outcome: "no_answer")))
      assert_equal "Contact completed", workspace(@volunteer).contact_work_item(@member, purpose: "buddy_check", assignment: @assignment)[:next_step]
    end
  end

  test "database rejects rewriting accepted contacts receipts and reviewed evidence" do
    operations.record(**buddy_payload)
    [ MembershipContact.sole, BuddyOperation.sole ].each do |record|
      assert_raises(ActiveRecord::StatementInvalid) do
        record.class.transaction(requires_new: true) { record.update_column(:created_at, Time.current) }
      end
      assert_raises(ActiveRecord::StatementInvalid) do
        record.class.transaction(requires_new: true) { record.class.where(id: record.id).delete_all }
      end
    end
    assert_equal 1, MembershipContact.count
    assert_equal 1, BuddyOperation.count
  end

  test "invalid event or follow-up rolls the entire operation back" do
    assert_raises(ArgumentError) do
      operations.record(**buddy_payload(follow_up: { due_at: "tomorrow", entry_zone: "America/Chicago" }))
    end
    assert_equal 0, MembershipContact.count
    assert_equal 0, BuddyOperation.count
    assert_raises(ArgumentError) { operations.record(**buddy_payload(facts: buddy_facts(outcome: "already_paid_online"))) }
    assert_raises(ArgumentError) { operations.record(**buddy_payload(facts: buddy_facts(entry_zone: "Imaginary/Zone"))) }
    assert_raises(ArgumentError) { operations.record(**buddy_payload(facts: buddy_facts(occurred_at: "2026-10-01T12:00:00"))) }
    assert_equal 0, MembershipDuesRecord.count
  end
end
