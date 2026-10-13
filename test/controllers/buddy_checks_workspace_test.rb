require "test_helper"
require_relative "../support/buddy_checks_helpers"

class BuddyChecksWorkspaceTest < ActionDispatch::IntegrationTest
  include BuddyChecksHelpers
  setup { setup_buddy_checks }
  teardown { restore_buddy_configuration }

  test "pilot member can use personal outreach without renewal or staff access" do
    sign_in_as(@other)
    get "/buddy-checks"
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "a[href='#{buddy_checks_contacts_path}']", text: /Your check history/
    assert_select "a[href='#{membership_buddy_attendances_path}']", count: 0
    get buddy_checks_people_path
    assert_response :success
    get buddy_checks_people_path, params: { q: "A" }
    assert_response :unprocessable_entity
    assert_select "input[name=q][value=A]"
    get buddy_checks_people_path, params: { q: "Alex" }
    assert_select ".workspace-destination", text: /Alex Member/
    get membership_root_path
    assert_response :forbidden
    get membership_buddy_attendances_path
    assert_response :forbidden
    get profile_path
    assert_select "#connected-apps a[href='#{mobile_sessions_path}']"
    get buddy_checks_person_path(@member)
    assert_select "a[href^='tel:']"
    assert_not_includes response.body, @member.member_number
  end

  test "web check and callback persist once and are visible through the mobile API" do
    sign_in_as(@other)
    values = { operation_id: SecureRandom.uuid, person_id: @member.id, occurred_at: local_time(1.hour.ago),
      channel: "phone", outcome: "reached", notes: "Agreed to call again", due_at: local_time(2.days.from_now) }
    2.times do
      post buddy_checks_contacts_path, params: { buddy_check: values }
      assert_redirected_to buddy_checks_person_path(@member)
    end
    assert_equal 1, MembershipContact.count
    assert_equal 1, BuddyFollowUp.count
    assert_equal @other, MembershipContact.sole.recorded_by
    assert_equal "buddy_check", MembershipContact.sole.purpose
    get buddy_checks_contacts_path
    assert_includes response.body, "Agreed to call again"
    get buddy_checks_follow_ups_path
    assert_includes response.body, "Alex Member"
    get "/api/mobile/v1/buddy-checks/mine", headers: mobile_headers
    assert_equal "Agreed to call again", response.parsed_body.fetch("items").sole.fetch("notes")
    get "/api/mobile/v1/buddy-checks/follow-ups", headers: mobile_headers
    assert_equal BuddyFollowUp.sole.id, response.parsed_body.fetch("items").sole.fetch("id")
  end

  test "web history excludes other caller notes and correction preserves originals and stale values" do
    mine = operations.record(**buddy_payload(facts: buddy_facts(notes: "Mine"))).fetch("contact")
    operations(@officer).record(**buddy_payload(facts: buddy_facts(notes: "Private officer note")))
    sign_in_as(@other)
    get buddy_checks_contacts_path
    assert_includes response.body, "Mine"
    assert_not_includes response.body, "Private officer note"
    values = { operation_id: SecureRandom.uuid, expected_revision: 1, channel: "text", outcome: "message_left", occurred_at: local_time(2.hours.ago), notes: "Corrected mine" }
    patch buddy_checks_contact_path(mine["id"]), params: { buddy_check: values }
    assert_response :see_other
    assert_equal "Mine", MembershipContact.find(mine["id"]).notes
    get buddy_checks_contacts_path
    assert_includes response.body, "Corrected mine"
    assert_not_includes response.body, ">Mine<"
    patch buddy_checks_contact_path(mine["id"]), params: { buddy_check: values.merge(operation_id: SecureRandom.uuid, notes: "Keep unsaved correction") }
    assert_response :conflict
    assert_select "textarea", text: "Keep unsaved correction"
    assert_equal 3, MembershipContact.count
    other_contact = MembershipContact.where(recorded_by: @officer).sole
    get edit_buddy_checks_contact_path(other_contact)
    assert_response :not_found
  end

  test "invalid contact retains values and pilot revocation or paused contact denies saving" do
    sign_in_as(@other)
    values = { operation_id: SecureRandom.uuid, person_id: @member.id, occurred_at: local_time(1.day.from_now), channel: "phone", outcome: "reached", notes: "Retain this" }
    post buddy_checks_contacts_path, params: { buddy_check: values }
    assert_response :unprocessable_entity
    assert_select "textarea", text: "Retain this"
    assert_select "input[name='buddy_check[operation_id]'][value='#{values[:operation_id]}']"
    assert_equal 0, MembershipContact.count
    @organization.membership_contacts.create!(person: @member, recorded_by: @officer, purpose: "buddy_check", membership_year: @year,
      occurred_on: Organization.current_local_date, channel: "phone", outcome: "do_not_contact", submission_key: SecureRandom.uuid)
    post buddy_checks_contacts_path, params: { buddy_check: values.merge(occurred_at: local_time(1.hour.ago)) }
    assert_response :forbidden
    assert_equal 1, MembershipContact.count
    @other.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    get buddy_checks_root_path
    assert_response :forbidden
    post buddy_checks_follow_ups_path, params: { callback: { operation_id: SecureRandom.uuid, person_id: @member.id, due_at: local_time(1.day.from_now) } }
    assert_response :forbidden
    assert_equal 0, BuddyFollowUp.count
  end

  test "callbacks and deferrals enforce ownership versions and later reads" do
    callback = operations.schedule(operation_id: SecureRandom.uuid, person_id: @member.id, due_at: 2.days.from_now.iso8601, entry_zone: "America/Chicago").fetch("follow_up")
    sign_in_as(@other)
    values = { operation_id: SecureRandom.uuid, expected_revision: 0, change: "reschedule", due_at: local_time(3.days.from_now) }
    patch buddy_checks_follow_up_path(callback["id"]), params: { callback: values }
    assert_response :see_other
    saved = BuddyFollowUp.find(callback["id"])
    assert_equal 1, saved.lock_version
    patch buddy_checks_follow_up_path(saved), params: { callback: values.merge(operation_id: SecureRandom.uuid) }
    assert_response :conflict
    get buddy_checks_follow_ups_path
    assert_includes response.body, "Alex Member"
    sign_in_as(@officer)
    patch buddy_checks_follow_up_path(saved), params: { callback: values.merge(expected_revision: 1, change: "cancel") }
    assert_response :not_found
    assert_equal "open", saved.reload.status
    sign_in_as(@other)
    patch buddy_checks_follow_up_path(saved), params: { callback: { operation_id: SecureRandom.uuid, expected_revision: 1, change: "complete" } }
    assert_response :see_other
    assert_equal "completed", saved.reload.status
    get buddy_checks_follow_ups_path
    assert_select "a", text: "Manage callback", count: 0
    post buddy_checks_snoozes_path, params: { operation_id: SecureRandom.uuid, person_id: @member.id }
    assert_response :see_other
    snooze = BuddySnooze.sole
    get buddy_checks_snoozes_path
    assert_includes response.body, "Alex Member"
    delete buddy_checks_snooze_path(snooze), params: { operation_id: SecureRandom.uuid, expected_revision: 0 }
    assert_response :see_other
    assert snooze.reload.cancelled_at
    get buddy_checks_snoozes_path
    assert_includes response.body, "No suggestions are deferred"
  end

  test "membership hub routes renewal work separately and staff evidence belongs to meetings" do
    sign_in_as(@officer)
    get membership_root_path
    assert_response :success
    assert_select "a[href='#{membership_follow_up_path(membership_year: @year)}']", text: /Renewal follow-up/
    assert_select "form[action='#{membership_follow_up_path}']", count: 0
    get membership_follow_up_path
    assert_select ".membership-task", count: 2
    meeting = buddy_meeting
    get meeting_path(meeting)
    assert_select "a[href='#{membership_buddy_attendance_path(meeting)}']"
    get buddy_checks_root_path
    assert_select "a[href='#{membership_buddy_attendances_path}']"
    get membership_person_path(@member)
    assert_select "form[action='#{membership_person_contacts_path(@member)}']", count: 0
    assert_select "a[href^='#{new_membership_person_contact_path(@member)}']"
  end

  test "date-only earlier contact retains its channel result and callback when preparing a correction" do
    original = @organization.membership_contacts.create!(person: @member, recorded_by: @other, purpose: "buddy_check", membership_year: @year,
      occurred_on: Organization.current_local_date - 5, channel: "email", outcome: "callback_requested", follow_up_on: Organization.current_local_date,
      notes: "Earlier email with date-only callback", submission_key: SecureRandom.uuid)
    sign_in_as(@other)
    get edit_buddy_checks_contact_path(original)
    assert_response :success
    assert_select "select[name='buddy_check[channel]'] option[selected][value=email]"
    assert_select "select[name='buddy_check[outcome]'] option[selected][value=callback_requested]"
    assert_select "input[name='buddy_check[occurred_on]']"
    values = { operation_id: SecureRandom.uuid, expected_revision: 1, channel: "email", outcome: "callback_requested", occurred_on: original.occurred_on.iso8601, notes: "Retain revised notes" }
    patch buddy_checks_contact_path(original), params: { buddy_check: values }
    assert_response :unprocessable_entity
    assert_select "textarea", text: "Retain revised notes"
    assert_equal 1, MembershipContact.count
    patch buddy_checks_contact_path(original), params: { buddy_check: values.merge(channel: "phone", outcome: "reached") }
    assert_response :see_other
    corrected = MembershipContact.effective.sole
    assert_nil corrected.occurred_at
    assert_equal original.follow_up_on, corrected.follow_up_on
    assert_equal "email", original.reload.channel
  end

  private

  def local_time(time)
    time.in_time_zone("America/Chicago").strftime("%Y-%m-%dT%H:%M")
  end
end
