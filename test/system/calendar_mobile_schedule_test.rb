require "application_system_test_case"

class CalendarMobileScheduleTest < ApplicationSystemTestCase
  test "day groups and event details are clear on narrow screens" do
    organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    user = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Reader"), email_address: "mobile-calendar@example.com")
    events = [
      [ "Community car and bike show", "public", "other", 5, "Riverside park", false ],
      [ "Car and bike show — Honor Guard", "members", "honor_guard", 5, "", true ],
      [ "Community festival planning meeting", "members", "planning_meeting", 8, "Community center, second-floor meeting room near the main entrance", false ]
    ].map do |title, visibility, category, day, location, cancelled|
      organization.calendar_events.create!(title:, visibility:, calendar_category: category, location:, cancelled:,
        starts_at: organization.calendar_time_zone.local(2026, 9, day, 9), created_by: user, updated_by: user)
    end
    system_sign_in(user)
    [ [ 390, 844 ], [ 320, 800 ], [ 1400, 1100 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit calendar_path(start_date: "2026-09-01")
      click_button "Schedule" if width > 560
      assert_selector ".calendar-date-group", count: 2
      within first(".calendar-date-group") do
        assert_selector ".calendar-date", count: 1
        assert_selector ".calendar-schedule-event", count: 2
        assert_selector ".calendar-grid-status", text: "Cancelled"
      end
      assert_selector ".calendar-schedule-kind", text: "Planning meetings"
      assert_selector ".calendar-event-place", text: "Community center, second-floor meeting room near the main entrance"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      page.execute_script("document.querySelector('.calendar-month-heading').scrollIntoView()")
      page.save_screenshot("/tmp/calendar-schedule-#{width}.png")
      first(".calendar-schedule-event").send_keys(:tab)
      assert_selector ".calendar-schedule-event:focus-visible"
      find(".calendar-schedule-event", text: "Community car and bike show").click
      assert_current_path calendar_event_path(events.first)
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end
end
