require "test_helper"
require_relative "../support/membership_workspace_helpers"

class MembershipWorkspaceTest < ActiveSupport::TestCase
  include MembershipWorkspaceHelpers

  setup { setup_membership_workspace }

  test "initial renewal year changes in the Post timezone at the July boundary" do
    travel_to Time.utc(2026, 7, 1, 2, 30) do
      assert_equal 2026, MembershipWorkspace.default_year
      @organization.update!(timezone: "Asia/Tokyo")
      assert_equal 2027, MembershipWorkspace.default_year
    end
  end

  test "local receipt and subsequent National confirmation remain distinct without counting the member twice" do
    original_roster = @member.attributes.slice("roster_paid_through_year", "roster_member_status", "roster_imported_at")
    record = workspace.record_dues!(dues_attributes)
    assert_equal "post_received", workspace.work_state(@member)
    assert_equal original_roster, @member.reload.attributes.slice(*original_roster.keys)
    assert_equal 1, workspace.summary.dig(:work_counts, "post_received")

    @member.update!(roster_paid_through_year: @year)
    assert_equal "confirmed", workspace.work_state(@member.reload)
    assert_equal 0, workspace.summary.dig(:work_counts, "post_received")
    assert_equal "45.0", workspace.summary[:post_dues_received]
    assert_equal record, @member.membership_dues_records.sole
  end

  test "a missing National paid year does not hide local payment or cause another renewal assignment" do
    @member.update!(roster_paid_through_year: nil)
    workspace.record_dues!(dues_attributes)
    assert_equal "unknown", workspace.report.renewal_state(@member.reload)
    assert_equal "post_received", workspace.work_state(@member)
    assert_not workspace.eligible_for_drive?(@member, @drive)
    assert_nil @member.roster_paid_through_year
  end

  test "National self report is unverified and a Post share check never renews an individual" do
    contact = workspace(@volunteer).record_contact!(contact_attributes(outcome: "already_paid_online"))
    assert_equal "national_reported", workspace.work_state(@member)
    assert_equal "needs_renewal", workspace.report.renewal_state(@member.reload)
    report = @member.membership_dues_records.sole
    assert_equal @volunteer, report.recorded_by
    assert_nil report.amount
    assert_equal contact.occurred_on, report.received_on

    workspace.record_dues!(dues_attributes(person_id: nil, kind: "post_share_received", amount: "130.25"))
    assert_equal "national_reported", workspace.work_state(@member)
    assert_equal "needs_contact", workspace.work_state(@unassigned)
    assert_equal "130.25", workspace.summary[:post_share_checks_received]
    assert_raises(ActiveRecord::RecordInvalid) { workspace.record_dues!(dues_attributes(kind: "post_share_received")) }
  end

  test "interrupted submissions can be retried but changed input and duplicate paper results are rejected" do
    attributes = contact_attributes(paper_reference: "#{@drive.id}-#{@assignment.id}-012345abcdef", outcome: "already_paid_online")
    contact = workspace(@volunteer).record_contact!(attributes)
    assert_no_difference [ "MembershipContact.count", "MembershipDuesRecord.count" ] do
      assert_equal contact, workspace(@volunteer).record_contact!(attributes)
    end
    assert_raises(MembershipWorkspace::Conflict) { workspace(@volunteer).record_contact!(attributes.merge(notes: "Different result")) }
    assert_raises(ActiveRecord::RecordInvalid) { workspace.record_contact!(attributes.merge(submission_key: SecureRandom.uuid)) }
    assert_equal 1, MembershipContact.count

    payment_attributes = dues_attributes
    receipt = workspace.record_dues!(payment_attributes)
    assert_equal receipt, workspace.record_dues!(payment_attributes)
    assert_raises(MembershipWorkspace::Conflict) { workspace.record_dues!(payment_attributes.merge(amount: "55.00")) }
  end

  test "corrections preserve the original and remove it from effective totals and later summaries" do
    receipt = workspace.record_dues!(dues_attributes)
    snapshot = workspace.save_summary!(submission_key: "before-correction")
    assert_not receipt.update(notes: "Overwritten")
    assert_not receipt.destroy
    correction = workspace.reverse_dues!(receipt.id, notes: "Entered for the wrong year", submission_key: "correct-receipt")
    assert_equal receipt, correction.reverses_record
    assert_equal "needs_contact", workspace.work_state(@member)
    assert_equal "0.0", workspace.summary[:post_dues_received]
    assert_equal "45.0", snapshot.reload.payload.fetch("post_dues_received")
    assert_equal 1, snapshot.payload.dig("work_counts", "post_received")
    assert_equal 0, snapshot.payload.dig("work_counts", "no_outreach")
    assert_equal snapshot, workspace.save_summary!(submission_key: "before-correction")
    assert_equal correction, workspace.reverse_dues!(receipt.id, notes: "Entered for the wrong year", submission_key: "correct-receipt")
    travel 1.day do
      assert_no_difference "MembershipDuesRecord.count" do
        assert_equal correction, workspace.reverse_dues!(receipt.id, notes: "Entered for the wrong year", submission_key: "correct-receipt")
      end
    end
    assert_raises(ActiveRecord::RecordInvalid) { workspace.reverse_dues!(receipt.id, notes: "Again", submission_key: "second-correction") }
    assert_equal 2, @member.membership_dues_records.count
    assert_not snapshot.update(payload: {})
  end

  test "paper entry preserves caller attribution and actual date ordering" do
    newer = workspace(@volunteer).record_contact!(contact_attributes(outcome: "callback_requested", follow_up_on: Organization.current_local_date + 3, notes: "Call Friday"))
    older = workspace.record_contact!(contact_attributes(occurred_on: Organization.current_local_date - 1, outcome: "no_answer"))
    assert_equal newer, workspace.last_contact(@member)
    assert_equal @volunteer, older.membership_assignment.assigned_to
    assert_equal @officer, older.recorded_by
    assert_not newer.update(notes: "Overwritten")
    assert_raises(ActiveRecord::RecordInvalid) { workspace.record_contact!(contact_attributes(outcome: "callback_requested")) }
    assert_raises(ActiveRecord::RecordInvalid) { workspace.record_contact!(contact_attributes(follow_up_on: "not-a-date")) }
  end

  test "volunteer access is restricted by person year and current assignment and cannot handle money" do
    assert_equal [ @member ], workspace(@volunteer).people
    assert_empty workspace(@volunteer, @year - 1).people
    assert_raises(ActiveRecord::RecordNotFound) { workspace(@other).person(@member.id) }
    assert_raises(ActiveRecord::RecordNotFound) { workspace(@volunteer).record_contact!(contact_attributes(person_id: @unassigned.id)) }
    assert_raises(MembershipWorkspace::AccessDenied) { workspace(@volunteer).record_dues!(dues_attributes) }
    @assignment.update!(revoked_at: Time.current)
    assert_empty workspace(@volunteer).people
    assert_raises(ActiveRecord::RecordNotFound) { workspace(@volunteer).record_contact!(contact_attributes) }
    @office.update!(ends_on: Organization.current_local_date - 1)
    assert_not workspace.access.manager?
    assert_raises(MembershipWorkspace::AccessDenied) { workspace.summary }
  end

  test "same day paper stays visible to its caller without replacing a digital callback" do
    callback = workspace(@volunteer).record_contact!(contact_attributes(outcome: "callback_requested", follow_up_on: Organization.current_local_date + 3))
    paper = workspace.record_contact!(contact_attributes(outcome: "no_answer", paper_reference: "#{@drive.id}-#{@assignment.id}-123456abcdef"))
    assert_equal callback, workspace.last_contact(@member)
    assert_equal callback, workspace(@volunteer).last_contact(@member)
    assert_includes workspace(@volunteer).contacts_for(@member), paper
    assert_equal @officer, paper.recorded_by

    review = workspace.record_contact!(contact_attributes(channel: "administrative_review", outcome: "callback_requested",
      follow_up_on: Organization.current_local_date + 5, notes: "Confirmed a later callback with the caller after reviewing the sheet"))
    assert_equal review, workspace.last_contact(@member)
    assert_equal review, workspace(@volunteer).last_contact(@member)
    assert_equal 3, workspace(@volunteer).contacts_for(@member).count
    assert_equal @year - 1, @member.reload.roster_paid_through_year
  end

  test "officer review requires an explanation and cannot be recorded by a volunteer" do
    attributes = contact_attributes(channel: "administrative_review", outcome: "officer_review")
    assert_raises(ActiveRecord::RecordInvalid) { workspace.record_contact!(attributes) }
    assert_raises(MembershipWorkspace::AccessDenied) { workspace(@volunteer).record_contact!(attributes.merge(notes: "Needs review")) }
    assert_empty @member.membership_contacts
  end

  test "paused outreach survives roster updates is purpose specific and requires an officer to restore" do
    workspace(@volunteer).record_contact!(contact_attributes(outcome: "do_not_contact"))
    @member.update!(roster_imported_at: Time.current, roster_paid_through_year: @year - 1)
    assert_equal "held", workspace.work_state(@member.reload)
    assert_raises(MembershipWorkspace::AccessDenied) { workspace(@volunteer).record_contact!(contact_attributes) }
    assert_raises(MembershipWorkspace::AccessDenied) { workspace(@volunteer).record_contact!(contact_attributes(outcome: "contact_permission_restored", notes: "Agreed")) }
    assert_not workspace.contact_paused?(@member, purpose: "buddy_check")
    workspace.record_contact!(contact_attributes(outcome: "contact_permission_restored", notes: "Member requested renewal help again"))
    assert_equal "needs_contact", workspace.work_state(@member)
    workspace(@volunteer).record_contact!(contact_attributes)
  end

  test "closed expired future disabled and removed assignments do not grant access" do
    @drive.update!(closed_at: Time.current)
    assert_empty workspace(@volunteer).people
    @drive.update!(closed_at: nil, starts_on: Organization.current_local_date + 1)
    assert_empty workspace(@volunteer).people
    @drive.update!(starts_on: Organization.current_local_date - 2)
    @assignment.update!(expires_on: Organization.current_local_date - 1)
    assert_empty workspace(@volunteer).people
    @assignment.update!(expires_on: @drive.ends_on)
    @volunteer.update!(disabled_at: Time.current)
    assert_empty workspace(@volunteer).people
    @volunteer.update!(disabled_at: nil)
    @member.update!(roster_removed_at: Time.current)
    assert_empty workspace(@volunteer).people
  end

  test "Buddy Checks reject dues solicitation outcomes" do
    @drive.update!(purpose: "buddy_check")
    assert_raises(ActiveRecord::RecordInvalid) { workspace(@volunteer).record_contact!(contact_attributes(outcome: "wants_to_renew")) }
    contact = workspace(@volunteer).record_contact!(contact_attributes(outcome: "reached"))
    assert_equal "buddy_check", contact.purpose
    assert_empty @member.membership_dues_records
  end

  test "volunteer work items follow the assigned purpose and separate completion from future callbacks" do
    @member.update!(roster_paid_through_year: @year)
    @drive.update!(purpose: "buddy_check")
    item = workspace(@volunteer).work_item(@member)
    assert item[:needs_attention]
    assert_equal "Make a Buddy Check", item[:next_step]
    assert_equal @assignment.id, item[:assignment_id]
    workspace(@volunteer).record_contact!(contact_attributes(outcome: "callback_requested", follow_up_on: Organization.current_local_date + 1))
    assert_not workspace(@volunteer).work_item(@member)[:needs_attention]
    travel 1.day do
      item = workspace(@volunteer).work_item(@member)
      assert item[:needs_attention]
      assert_equal "Make the agreed callback", item[:next_step]
      workspace(@volunteer).record_contact!(contact_attributes(outcome: "reached"))
      assert_not workspace(@volunteer).work_item(@member)[:needs_attention]
    end
    assert_equal @year, @member.reload.roster_paid_through_year
  end

  test "invalid or fractional cent amounts cannot become rounded receipts" do
    %w[0 -10 not-money 45.999 10000000000].each do |amount|
      assert_raises(ActiveRecord::RecordInvalid) { workspace.record_dues!(dues_attributes(amount:)) }
    end
    assert_empty @member.membership_dues_records
  end

  test "deceased and removed records never become contact work despite earlier callbacks and receipts" do
    workspace.record_contact!(contact_attributes(outcome: "callback_requested", follow_up_on: Organization.current_local_date))
    workspace.record_dues!(dues_attributes)
    snapshot = workspace.save_summary!(submission_key: "before-roster-change")
    [ { roster_member_status: " Deceased " }, { roster_member_status: "Active", roster_removed_at: Time.current } ].each do |change|
      @member.update!(change)
      current = workspace
      assert_equal "no_outreach", current.work_state(@member.reload)
      assert_not current.work_item(@member)[:needs_attention]
      assert_nil current.work_item(@member)[:follow_up_on]
      assert_equal 1, current.summary.dig(:work_counts, "no_outreach")
      assert_equal 0, current.summary.dig(:work_counts, "review")
      %w[renewal welcome buddy_check].each do |purpose|
        @drive.update!(purpose:)
        assert_not current.eligible_for_drive?(@member, @drive)
      end
      assert_no_difference "MembershipContact.count" do
        assert_raises(MembershipWorkspace::AccessDenied) { current.record_contact!(contact_attributes(membership_assignment_id: nil)) }
      end
    end
    assert_equal "45.0", snapshot.reload.payload.fetch("post_dues_received")
    assert_equal 1, @member.membership_contacts.count
    assert_equal 1, @member.membership_dues_records.count
  end

  test "renewal candidates exclude declined deferred and uncertain records but retain expired members" do
    workspace.record_contact!(contact_attributes(outcome: "declined_renewal"))
    assert_not workspace.eligible_for_drive?(@member, @drive)
    workspace.record_contact!(contact_attributes(outcome: "callback_requested", follow_up_on: Organization.current_local_date + 1))
    assert_not workspace.eligible_for_drive?(@member, @drive)
    travel 1.day do
      assert workspace.eligible_for_drive?(@member, @drive)
    end
    @unassigned.update!(roster_paid_through_year: nil)
    assert workspace.work_item(@unassigned)[:needs_attention], "Officers still need to review uncertain standing"
    assert_not workspace.eligible_for_drive?(@unassigned, @drive)
    @unassigned.update!(roster_member_status: "Expired")
    assert workspace.eligible_for_drive?(@unassigned, @drive)
    @drive.update!(purpose: "buddy_check")
    @unassigned.update!(roster_member_status: "Active", roster_paid_through_year: @year)
    assert workspace.eligible_for_drive?(@unassigned, @drive)
  end
end
