require "application_system_test_case"

class CalendarRefinementsTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1000)
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Editor"), email_address: "calendar-editor@example.com")
    @user.permission_grants.create!(capability: "manage_settings")
    @user.permission_grants.create!(capability: "manage_agendas")
    { "member_meeting" => "Membership Meeting", "officer_meeting" => "Officers planning",
      "honor_guard" => "Honor Guard practice", "planning_meeting" => "Festival planning meeting", "other" => "Community breakfast" }.each_with_index do |(category, title), index|
      @organization.calendar_events.create!(title: title, calendar_category: category,
        starts_at: @organization.calendar_time_zone.local(2026, 9, 8 + index, 8), created_by: @user, updated_by: @user)
    end
    @organization.calendar_events.create!(title: "Post picnic", visibility: "public", all_day: true,
      starts_at: @organization.calendar_time_zone.local(2026, 9, 19), created_by: @user, updated_by: @user)
  end

  teardown do
    page.current_window.resize_to(1400, 1000)
  end

  test "readable calendar filters and forgiving time entry at desktop and phone widths" do
    system_sign_in(@user)
    visit manage_calendar_path(start_date: "2026-09-01")
    assert_selector ".calendar-grid th:first-child", text: "SUN"
    assert_selector ".calendar-grid th:last-child", text: "SAT"
    page.save_screenshot("/tmp/calendar-refinements-desktop.png")
    uncheck "Member Meeting"
    uncheck "Officer Meeting"
    uncheck "Other activities"
    assert_no_selector ".calendar-grid-event", text: "Membership Meeting"
    assert_selector ".calendar-grid-event", text: "Honor Guard practice"
    find("a[aria-label='Next month']").click
    assert_unchecked_field "Member Meeting"
    assert_checked_field "Honor Guard"
    find("a[aria-label='Previous month']").click
    page.current_window.resize_to(390, 844)
    assert_no_selector ".calendar-grid"
    assert_selector ".calendar-row", text: "Honor Guard practice"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot("/tmp/calendar-refinements-mobile.png")
    page.execute_script("document.querySelector('.calendar-schedule').scrollIntoView()")
    page.save_screenshot("/tmp/calendar-refinements-mobile-schedule.png")
    click_link "+ Add event"
    fill_in "Event name", with: "Morning volunteer setup"
    select "Planning meetings", from: "Calendar event type"
    fill_in "calendar_event_starts_at_date", with: "12 SEP 2026"
    fill_in "calendar_event_starts_at_time", with: "800"
    find("#calendar_event_starts_at_time").send_keys(:tab)
    assert_field "calendar_event_starts_at_time", with: "08:00"
    page.save_screenshot("/tmp/calendar-refinements-form.png")
    click_button "Add event"
    assert_selector "h1", text: "Morning volunteer setup"
    assert_text "08:00"
    page.save_screenshot("/tmp/calendar-redesign-event-detail.png")
  end

  test "member discovers events and filters Honor Guard with visible controls" do
    member = User.create!(person: Person.create!(first_name: "General", last_name: "Member"), email_address: "calendar-reader@example.com")
    system_sign_in(member)
    visit calendar_path(start_date: "2026-09-01")
    assert_no_link "Manage calendar"
    assert_no_link "+ Add event"
    assert_no_link "Public event preview"
    assert_no_selector "select"
    assert_no_selector "details"
    assert_no_selector "h1", text: "Calendar"
    assert_no_text "Meet, take part, lend a hand."
    assert_no_field "Volunteers"
    assert_selector ".calendar-category--public_event.calendar-grid-event", text: "Post picnic"
    assert_no_selector ".calendar-grid-event", text: "Date only"
    assert_selector ".calendar-grid-event .calendar-block-time", text: "08:00"
    assert_selector ".calendar-grid-event", text: "Officers planning"
    assert_selector ".calendar-grid-event", text: "Festival planning meeting"
    block = find(".calendar-grid-event", text: "Festival planning meeting")
    assert_equal "none", block.style("text-decoration-line")["text-decoration-line"]
    assert_not_equal "rgba(0, 0, 0, 0)", block.style("background-color")["background-color"]
    page.save_screenshot("/tmp/calendar-redesign-member-desktop.png")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_selector ".calendar-schedule-event", text: "Officers planning"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    click_button "Schedule"
    assert_selector ".calendar-schedule-event", text: "Membership Meeting"
    assert_no_selector ".calendar-grid"
    click_button "Clear"
    assert_text "No events to show"
    page.refresh
    assert_text "No events to show"
    check "Honor Guard"
    assert_selector ".calendar-schedule-event", text: "Honor Guard practice"
    assert_no_selector ".calendar-schedule-event", text: "Membership Meeting"
    assert_includes page.current_url, "honor_guard"
    assert_selector "#category_honor_guard:focus"
    page.current_window.resize_to(390, 844)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot("/tmp/calendar-redesign-honor-guard-mobile.png")
    click_button "All types"
    assert_selector ".calendar-schedule-event", text: "Festival planning meeting"
    page.save_screenshot("/tmp/calendar-redesign-member-mobile.png")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_no_selector ".calendar-filters"
    assert_selector ".calendar-schedule-event", text: "Officers planning"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
  end

  test "event details stay legible with neutral colors and show timezone only for timed events" do
    member = User.create!(person: Person.create!(first_name: "Event", last_name: "Reader"), email_address: "event-reader@example.com")
    event = @organization.calendar_events.find_by!(calendar_category: "other")
    event.update!(location: "Post hall", description: "Join us for breakfast and conversation.

Setup begins before the doors open; see the organizer for details.")
    system_sign_in(member)
    visit calendar_event_path(event)
    assert_selector ".calendar-event-heading .calendar-event-type", text: /Other activities/i
    assert_selector ".calendar-event-timezone", text: "America/Chicago"
    assert_no_link "Edit event"
    page.save_screenshot("/tmp/calendar-detail-neutral-desktop.png")
    page.current_window.resize_to(390, 844)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot("/tmp/calendar-detail-neutral-mobile.png")
    visit calendar_event_path(@organization.calendar_events.find_by!(calendar_category: "honor_guard"))
    assert_selector ".calendar-event-type", text: /Honor Guard/i
    page.save_screenshot("/tmp/calendar-detail-honor-guard-mobile.png")
    visit calendar_event_path(@organization.calendar_events.find_by!(title: "Post picnic"))
    assert_selector ".calendar-event-type", text: /Public events/i
    assert_no_selector ".calendar-event-timezone"
    assert_no_text "America/Chicago"
    page.save_screenshot("/tmp/calendar-detail-date-only-mobile.png")
  end
end
