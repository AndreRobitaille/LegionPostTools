require "application_system_test_case"
require_relative "../support/buddy_checks_helpers"

class BuddyChecksWorkspaceSystemTest < ApplicationSystemTestCase
  include BuddyChecksHelpers

  setup do
    setup_buddy_checks
    page.current_window.resize_to(1400, 1000)
  end

  teardown do
    restore_buddy_configuration
    page.current_window.resize_to(1400, 1000)
  end

  test "pilot caller records checks and callbacks through the task workspace on desktop and phone" do
    operations(@officer).record(**buddy_payload(facts: buddy_facts(notes: "Other caller private detail", occurred_at: 100.days.ago.iso8601)))
    system_sign_in(@other)
    visit buddy_checks_root_path
    assert_selector "h1", text: "Buddy Checks"
    assert_no_link "General-member attendance"
    assert_no_text "Other caller private detail"
    capture_layouts("buddy-workspace-home")
    find("a", text: "Find a member", exact: false).send_keys(:tab)
    focus = page.evaluate_script("({width: getComputedStyle(document.activeElement).outlineWidth, offset: getComputedStyle(document.activeElement).outlineOffset})")
    assert_equal "3px", focus["width"]
    assert_equal "-3px", focus["offset"]
    click_link "Find a member", exact: false
    fill_in "Member name", with: "Alex"
    click_button "Find members"
    assert_selector ".mrow-list .workspace-destination", count: 1
    click_link "Alex Member"
    assert_text "Available for a Buddy Check"
    assert_no_text "Other caller private detail"
    capture_layouts("buddy-workspace-prepare")
    click_link "Record a Buddy Check", exact: false
    fill_in "Contact date and time", with: local_time(1.hour.ago)
    fill_in "Brief notes", with: "Offered help with a visit; agreed another call"
    fill_in "Agreed callback date and time (optional)", with: local_time(2.days.from_now)
    capture_layouts("buddy-workspace-record")
    click_button "Record Buddy Check"
    assert_text "Buddy Check recorded."
    assert_text "Offered help with a visit; agreed another call"
    contact = MembershipContact.where(recorded_by: @other).sole
    callback = BuddyFollowUp.sole
    assert_equal "reached", contact.outcome
    assert_equal contact.id, callback.membership_contact_id
    visit buddy_checks_contacts_path
    assert_text "Offered help with a visit; agreed another call"
    assert_no_text "Other caller private detail"
    capture_layouts("buddy-workspace-history")
    click_link "Correct this check"
    select "Message left", from: "What happened?"
    fill_in "Brief notes", with: "Correction: left a message about a visit"
    click_button "Save correction"
    assert_text "Correction saved. The original check is preserved."
    assert_text "Correction: left a message about a visit"
    assert_equal "Offered help with a visit; agreed another call", contact.reload.notes
    assert_equal 2, MembershipContact.where(recorded_by: @other).count
    click_link "Your callbacks", exact: true
    assert_text "Alex Member"
    capture_layouts("buddy-workspace-callbacks")
    click_link "Manage callback"
    fill_in "Agreed callback date and time", with: local_time(3.days.from_now)
    click_button "Save new callback time"
    assert_text "Callback rescheduled."
    assert_equal 1, callback.reload.lock_version
    click_link "Manage callback"
    capture_layouts("buddy-workspace-manage-callback")
    click_button "Mark callback complete"
    assert_text "Callback marked complete."
    assert_equal "completed", callback.reload.status
    visit buddy_checks_follow_ups_path
    assert_text "No open callbacks"
    @other.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    visit buddy_checks_root_path
    assert_no_text "Correction: left a message about a visit"
    assert_no_link "Buddy Checks", exact: true
  end

  test "phone caller defers and restores suggestions and recovers an invalid form" do
    system_sign_in(@other)
    page.current_window.resize_to(390, 844)
    visit buddy_checks_person_path(@member)
    click_button "Defer suggestion for seven days"
    assert_text "Suggestion deferred for seven days."
    visit buddy_checks_snoozes_path
    assert_text "Alex Member"
    capture_system_screenshot("buddy-workspace-deferred-phone")
    click_button "Restore suggestion"
    assert_text "Suggestion restored."
    assert BuddySnooze.sole.reload.cancelled_at
    visit new_buddy_checks_contact_path(person_id: @member.id)
    fill_in "Contact date and time", with: local_time(1.day.from_now)
    fill_in "Brief notes", with: "Keep the entered notes"
    click_button "Record Buddy Check"
    assert_text "Check the date, time, and result"
    assert_field "Brief notes", with: "Keep the entered notes"
    capture_system_screenshot("buddy-workspace-invalid-phone")
    assert_layout
    assert_equal 0, MembershipContact.count
    fill_in "Contact date and time", with: local_time(1.hour.ago)
    click_button "Record Buddy Check"
    assert_text "Buddy Check recorded."
    assert_equal "Keep the entered notes", MembershipContact.sole.notes
    visit buddy_checks_contacts_path
    assert_text "Keep the entered notes"
  end

  test "manager task hub meeting attendance and profile connections fit desktop tablet and phone" do
    @officer.permission_grants.create!(capability: "manage_settings")
    @member.update!(first_name: "Alexandria-Catherine", last_name: "Long Member Name for Calling Team")
    meeting = buddy_meeting
    system_sign_in(@officer)
    visit membership_root_path
    assert_link "Renewal follow-up", exact: false
    assert_no_link "General-member attendance"
    capture_layouts("membership-task-home")
    click_link "Renewal follow-up", exact: false
    assert_link @member.roster_display_name
    capture_layouts("membership-task-renewals")
    click_link @member.roster_display_name
    assert_link "Review mailing address", exact: false
    assert_no_button "Record contact"
    capture_layouts("membership-task-member")
    click_link "Record contact or review", exact: false
    assert_button "Record contact"
    capture_layouts("membership-task-contact")
    visit membership_drive_path(@drive)
    capture_layouts("membership-task-drive")
    visit meeting_path(meeting)
    click_link "Review general-member attendance"
    fill_in "How was this general-member list checked?", with: "Reviewed the synthetic sign-in sheet"
    assert_text "2 not recorded in the whole register"
    fill_in "Find a member in this register", with: "Alexandria"
    select "Absent", from: @member.full_name
    assert_no_selector ".attendance-member", text: "Taylor Member"
    assert_text "1 absent"
    fill_in "Find a member in this register", with: ""
    select "Present", from: "Taylor Member"
    assert_text "0 not recorded"
    capture_layouts("membership-task-attendance")
    check "I reviewed attendance for every member listed"
    click_button "Save attendance revision"
    assert_text "General-member attendance saved."
    assert_equal 2, BuddyAttendanceRegister.sole.entries.size
    assert_equal "absent", BuddyAttendanceRegister.sole.entries.fetch(@member.id.to_s)
    visit membership_buddy_attendance_path(meeting)
    assert_equal "absent", find_field(@member.full_name).value
    assert_equal 0, MeetingMinutes.count
    visit profile_path
    assert_selector "#connected-apps", text: "Buddy Checks app connections"
    capture_layouts("profile-connected-apps", selector: "#connected-apps")
    click_link "Buddy Checks app connections", exact: false
    assert_link "Your profile"
    assert_text "No active app connections"
    capture_layouts("profile-app-connections")
  end

  private

  def local_time(time)
    time.in_time_zone("America/Chicago").change(sec: 0)
  end

  def capture_layouts(name, selector: nil)
    [ [ 1400, 1000 ], [ 900, 1000 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      page.execute_script("window.scrollTo(0, 0)") unless selector
      find("body").scroll_to(find(selector), align: :top) if selector
      assert_layout
      capture_system_screenshot("#{name}-#{width}")
    end
  end

  def assert_layout
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "No horizontal page scrolling"
    fonts = page.evaluate_script("Array.from(document.querySelectorAll('main input:not([type=hidden]):not([type=checkbox]), main select, main button, main textarea')).filter(e => e.getClientRects().length).map(e => parseFloat(getComputedStyle(e).fontSize))")
    assert fonts.all? { |size| size >= 16 }, fonts.inspect
    targets = page.evaluate_script("Array.from(document.querySelectorAll('.task-workspace .btn-primary, .task-workspace .btn-secondary, .buddy-form .f, .membership-form .f, .attendance-member select')).filter(e => e.getClientRects().length).map(e => e.getBoundingClientRect().height)")
    assert targets.all? { |height| height >= 44 }, targets.inspect
    if page.current_window.size.first == 1400
      nav_rows = page.evaluate_script("Array.from(new Set(Array.from(document.querySelectorAll('.nav-tab')).map(e => e.getBoundingClientRect().top)))")
      assert_equal 1, nav_rows.size, "Desktop destinations must fit a single navigation row"
    end
  end
end
