require "test_helper"
require_relative "../support/buddy_checks_helpers"

class BuddyCheckCoordinationTest < ActionDispatch::IntegrationTest
  include BuddyChecksHelpers

  setup do
    travel_to Time.zone.local(2026, 11, 15, 12)
    setup_buddy_checks
    @title.update!(name: "1st Vice Commander")
  end

  teardown do
    restore_buddy_configuration
    travel_back
  end

  test "mobile checks appear in Post activity and member history without renewal or dues records" do
    values = buddy_payload(facts: buddy_facts(occurred_at: "2026-10-20T18:00:00Z", notes: "Offered a ride to the next gathering"))
    2.times do
      post "/api/mobile/v1/buddy-checks", params: values, headers: mobile_headers, as: :json
      assert_response :created
    end
    @organization.membership_contacts.create!(contact_record(purpose: "renewal", notes: "DUES_NOTE_CANARY"))
    assert_equal 1, @organization.membership_contacts.where(purpose: "buddy_check").count
    @officer.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    sign_in_as(@officer)
    get buddy_checks_root_path
    assert_redirected_to buddy_checks_activity_path
    follow_redirect!
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_includes response.body, "Offered a ride"
    assert_select ".buddy-post-check", text: /Recorded by Other Helper/
    assert_not_includes response.body, "DUES_NOTE_CANARY"
    get buddy_checks_member_history_path(@member)
    assert_includes response.body, "Offered a ride"
    assert_not_includes response.body, "DUES_NOTE_CANARY"
    assert_not_includes response.body, "Dues and reported payments"
    get membership_person_path(@member)
    assert_not_includes response.body, "Offered a ride"
    assert_includes response.body, "DUES_NOTE_CANARY"
  end

  test "county counts reached checks in the Post month and counts current revisions only" do
    reached = operations.record(**buddy_payload(facts: buddy_facts(occurred_at: "2026-11-01T00:30:00Z", notes: "PRIVATE_CHECK_CANARY"))).fetch("contact")
    operations.record(**buddy_payload(facts: buddy_facts(occurred_at: "2026-10-10T18:00:00Z", outcome: "reached"),
      follow_up: { due_at: 3.days.from_now.iso8601, entry_zone: "America/Chicago" }))
    operations.record(**buddy_payload(facts: buddy_facts(occurred_at: "2026-10-11T18:00:00Z", outcome: "no_answer")))
    operations.record(**buddy_payload(facts: buddy_facts(occurred_at: "2026-10-12T18:00:00Z", outcome: "message_left")))
    @organization.membership_contacts.create!(contact_record(person: @unassigned, occurred_on: Date.new(2026, 10, 13), channel: "administrative_review", outcome: "do_not_contact", notes: "PREFERENCE_CANARY"))
    @organization.membership_contacts.create!(contact_record(occurred_on: Date.new(2026, 10, 14), outcome: "not_attempted"))
    @organization.membership_contacts.create!(contact_record(occurred_on: Date.new(2026, 10, 14), purpose: "renewal", notes: "DUES_CANARY"))
    care = care_attributes(notes: "CARE_CANARY")
    BuddyCareUpdate.record!(user: @officer, organization: @organization, person: @member, expected_revision: 0, attributes: care)
    sign_in_as(@officer)
    get buddy_checks_report_path, params: { month: "2026-10" }
    assert_select ".buddy-county-number strong", text: "2"
    assert_select ".buddy-monthly-total", text: /October 2026/
    %w[PRIVATE_CHECK_CANARY PREFERENCE_CANARY DUES_CANARY CARE_CANARY].each { |value| assert_not_includes response.body, value }
    assert_select ".buddy-monthly-total", text: /Alex Member/, count: 0
    get buddy_checks_report_path, params: { month: "2026-11" }
    assert_select ".buddy-county-number strong", text: "0"
    operations.correct(operation_id: SecureRandom.uuid, id: reached["id"], expected_revision: 1,
      facts: buddy_facts(occurred_at: "2026-11-01T00:30:00Z", outcome: "no_answer"))
    get buddy_checks_report_path, params: { month: "2026-10" }
    assert_select ".buddy-county-number strong", text: "1"
    assert_equal 2, MembershipContact.where(logical_contact_id: [ nil, reached["id"] ], recorded_by: @other, outcome: "no_answer").count
    get buddy_checks_report_path, params: { month: "2026-13" }
    assert_response :unprocessable_entity
    assert_select ".buddy-county-number", count: 0
  end

  test "care coverage respects no-contact requests and missing attendance remains unknown" do
    operations.record(**buddy_payload(facts: buddy_facts(occurred_at: 80.days.ago.iso8601)))
    BuddyCareUpdate.record!(user: @officer, organization: @organization, person: @unassigned, expected_revision: 0, attributes: care_attributes)
    sign_in_as(@officer)
    get buddy_checks_coverage_path
    assert_equal "Taylor Member", css_select(".buddy-coverage-row h2 a").first.text
    assert_select ".buddy-coverage-row", count: 2
    assert_includes response.body, "Unknown — no attendance recorded"
    assert_not_includes response.body, "Absent at the latest two"
    values = { outcome: "do_not_contact", notes: "Member asked for a pause", submission_key: SecureRandom.uuid }
    2.times { post buddy_checks_preference_path(@member), params: { preference: values }; assert_response :see_other }
    assert_equal 1, @organization.membership_contacts.where(outcome: "do_not_contact").count
    get buddy_checks_coverage_path
    assert_select ".buddy-coverage-row", count: 1
    assert_select ".buddy-coverage-row", text: /Alex Member/, count: 0
    get buddy_checks_coverage_path, params: { filter: "no_contact" }
    assert_select ".buddy-coverage-row", count: 1
    assert_select ".buddy-coverage-row", text: /Alex Member.*No Buddy Check contact requested/m
    post buddy_checks_preference_path(@member), params: { preference: values.merge(outcome: "contact_permission_restored", notes: "Member agreed to resume", submission_key: SecureRandom.uuid) }
    assert_response :see_other
    get buddy_checks_coverage_path
    assert_select ".buddy-coverage-row", count: 2
  end

  test "only two complete explicit absences trigger an alert and a later incomplete revision interrupts it" do
    meetings = [ buddy_meeting(days_ago: 35), buddy_meeting(days_ago: 5) ]
    meetings.each { |meeting| attendance(meeting, "absent", complete: true) }
    sign_in_as(@officer)
    get buddy_checks_coverage_path
    assert_select ".buddy-coverage-row", text: /Alex Member.*Absent at the latest two covered meetings/m
    attendance(meetings.last, "not_recorded", complete: false, expected_revision: 1)
    get buddy_checks_coverage_path
    assert_not_includes response.body, "Absent at the latest two"
    assert_includes response.body, "Unknown — no attendance recorded"
    attendance(meetings.last, "present", complete: true, expected_revision: 2)
    get buddy_checks_coverage_path
    assert_not_includes response.body, "Absent at the latest two"
    assert_select ".buddy-coverage-row", text: /Alex Member.*10 NOV 2026/m
  end

  test "private care updates survive retries stale forms and later resolution" do
    sign_in_as(@officer)
    attributes = care_attributes(notes: "Arrange a visit with a trusted Post contact")
    2.times do
      post buddy_checks_care_path(@member), params: { care: attributes.merge(expected_revision: 0) }
      assert_response :see_other
    end
    first = BuddyCareUpdate.sole
    assert_equal @officer, first.assigned_to
    assert_equal 1, first.revision
    get buddy_checks_activity_path
    assert_select "aside[aria-label='Care follow-up due']", text: /1 private care review/
    get buddy_checks_coverage_path, params: { filter: "extra_care" }
    assert_includes response.body, first.notes
    assert_includes response.body, "Follow-up owner: Officer Helper"
    post buddy_checks_care_path(@member), params: { care: attributes.merge(expected_revision: 0, submission_key: SecureRandom.uuid, notes: "Keep these unsaved notes") }
    assert_response :conflict
    assert_select "textarea", text: "Keep these unsaved notes"
    assert_equal 1, BuddyCareUpdate.count
    post buddy_checks_care_path(@member), params: { care: attributes.merge(expected_revision: 1, status: "cleared", notes: "Visit completed; review settled", submission_key: SecureRandom.uuid) }
    assert_response :see_other
    assert_equal 2, BuddyCareUpdate.count
    assert_equal "Arrange a visit with a trusted Post contact", first.reload.notes
    assert_not first.update(notes: "Overwrite history")
    first.reload
    %i[update delete].each do |operation|
      error = assert_raises(ActiveRecord::StatementInvalid) do
        BuddyCareUpdate.transaction(requires_new: true) do
          scope = BuddyCareUpdate.where(id: first.id)
          operation == :update ? scope.update_all(notes: "Overwrite history") : scope.delete_all
        end
      end
      assert_includes error.message, "Buddy Check evidence is append-only"
      assert_equal "Arrange a visit with a trusted Post contact", first.reload.notes
    end
    get buddy_checks_member_history_path(@member)
    assert_includes response.body, "Care review complete"
    assert_includes response.body, first.notes
    get buddy_checks_coverage_path, params: { filter: "extra_care" }
    assert_select ".buddy-coverage-row", count: 0
  end

  test "ordinary caller cannot read Post history or care notes and expired leadership cannot write" do
    BuddyCareUpdate.record!(user: @officer, organization: @organization, person: @member, expected_revision: 0, attributes: care_attributes(notes: "CARE_PRIVATE"))
    sign_in_as(@other)
    [ buddy_checks_activity_path, buddy_checks_coverage_path, buddy_checks_report_path, buddy_checks_member_history_path(@member), buddy_checks_care_path(@member) ].each do |path|
      get path
      assert_response :forbidden
      assert_not_includes response.body, "CARE_PRIVATE"
    end
    post buddy_checks_care_path(@member), params: { care: care_attributes.merge(expected_revision: 1) }
    assert_response :forbidden
    get buddy_checks_person_path(@member)
    assert_not_includes response.body, "CARE_PRIVATE"
    get "/api/mobile/v1/buddy-checks/people/#{@member.id}", headers: mobile_headers
    assert_not_includes response.body, "CARE_PRIVATE"
    sign_in_as(@officer)
    @office.update!(ends_on: Organization.current_local_date - 1)
    post buddy_checks_care_path(@member), params: { care: care_attributes.merge(expected_revision: 1) }
    assert_response :forbidden
    assert_equal 1, BuddyCareUpdate.count
  end

  test "care owner losing access after the form opens is rejected and invalid values remain visible" do
    grant = @other.permission_grants.create!(capability: "manage_people")
    sign_in_as(@officer)
    get buddy_checks_care_path(@member)
    assert_select "select[name='care[assigned_to_id]'] option[value=?]", @other.id.to_s
    grant.destroy!
    post buddy_checks_care_path(@member), params: { care: care_attributes(assigned_to_id: @other.id).merge(expected_revision: 0) }
    assert_response :unprocessable_entity
    assert_select "textarea", text: "Arrange a check-in"
    assert_equal 0, BuddyCareUpdate.count
    get buddy_checks_coverage_path, params: { days: "wrong", q: "A" }
    assert_response :unprocessable_entity
    assert_select ".buddy-coverage-row", count: 0
  end

  private

  def care_attributes(**changes)
    { status: "needs_attention", assigned_to_id: @officer.id, follow_up_on: Organization.current_local_date,
      notes: "Arrange a check-in", submission_key: SecureRandom.uuid }.merge(changes)
  end

  def contact_record(**changes)
    { person: @member, recorded_by: @officer, purpose: "buddy_check", membership_year: @year,
      occurred_on: Organization.current_local_date, channel: "phone", outcome: "reached", submission_key: SecureRandom.uuid }.merge(changes)
  end

  def attendance(meeting, status, complete:, expected_revision: 0)
    BuddyAttendanceRegister.record!(meeting:, user: @officer, expected_revision:, complete:, coverage_note: "Synthetic reviewed register",
      entries: { @member.id.to_s => status, @unassigned.id.to_s => "present" })
  end
end
