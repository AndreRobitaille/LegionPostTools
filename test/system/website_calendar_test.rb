require "application_system_test_case"
require_relative "../support/website_publishing_support"

class WebsiteCalendarSystemTest < ApplicationSystemTestCase
  include WebsitePublishingSupport
  setup do
    setup_publisher
    Installation.singleton.update!(setup_completed_at: Time.current)
    @publisher.permission_grants.create!(capability: "manage_settings")
    @publisher.permission_grants.create!(capability: "manage_agendas")
  end
  teardown { teardown_publisher }

  test "standalone event meeting and reviewed defaults work at desktop and phone widths" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    system_sign_in(@publisher)
    visit new_calendar_event_path
    fill_in "Event name", with: "Synthetic community supper"
    select "Public events", from: "Calendar event type"
    fill_in "calendar_event_starts_at_date", with: "03 Oct 2026"
    fill_in "calendar_event_starts_at_time", with: "18:00"
    fill_in "Place or address", with: "Post hall"
    select "Open to the public", from: "Who may attend?"
    fill_in "Public description (optional)", with: "Community supper at the hall."
    click_button "Add event"
    assert_text "Event added to the calendar."
    event = CalendarEvent.find_by!(title: "Synthetic community supper")
    assert_current_path calendar_event_path(event)
    assert_nil event.endeavor_id
    visit admin_website_calendar_path
    click_button "Review defaults"
    assert_current_path preview_admin_website_calendar_path
    assert_selector "section.website-calendar-preview", text: "Synthetic community supper"
    assert_text "1 shown; 0 hidden"
    assert_no_horizontal_overflow
    capture_system_screenshot("website-calendar-desktop")
    page.driver.browser.manage.window.resize_to(390, 844)
    assert_no_horizontal_overflow
    find(".website-calendar-preview").scroll_to(:top)
    capture_system_screenshot("website-calendar-mobile")
    click_button "Activate calendar listings"
    assert_current_path admin_website_calendar_path
    assert_text "Website calendar defaults saved."
    visit edit_calendar_event_path(event)
    assert_selector ".website-calendar-fields"
    assert_no_horizontal_overflow
    find(".website-calendar-fields").scroll_to(:top)
    capture_system_screenshot("website-calendar-event-mobile")
    select "Hide", from: "Public website"
    click_button "Save event"
    assert_current_path calendar_event_path(event)
    assert_text "Calendar event saved."
    assert_not event.reload.website_listed?

    @organization.meeting_bodies.create!(name: "Membership", slug: "membership", default_location_name: "Post hall")
    visit new_admin_meeting_path
    select "Member Meeting", from: "Calendar event type"
    fill_in "Public description (optional)", with: "Monthly membership meeting."
    assert_no_horizontal_overflow
    capture_system_screenshot("website-calendar-meeting-mobile")
    click_button "Create meeting"
    assert_text "Meeting created."
    meeting = Meeting.order(:id).last
    assert_current_path admin_meeting_path(meeting)
    assert_text "Shown"
    assert_equal "members", meeting.attendance
    assert_nil meeting.dated_agenda
  end

  private

  def assert_no_horizontal_overflow
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("window.innerWidth")
  end
end
