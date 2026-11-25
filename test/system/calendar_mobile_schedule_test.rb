require "application_system_test_case"

class CalendarMobileScheduleTest < ApplicationSystemTestCase
  test "members can open the calendar choices and download one event from the event and meeting pages" do
    post = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    member = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Reader"), email_address: "dates@example.com")
    body = post.meeting_bodies.create!(name: "Membership", slug: "membership")
    start = post.calendar_time_zone.now.advance(days: 5).change(hour: 19)
    event = post.calendar_events.create!(title: "Community supper", location: "Lakeside Pavilion",
      starts_at: start, ends_at: start + 2.hours, created_by: member, updated_by: member)
    meeting = create_meeting!(organization: post, meeting_body: body, starts_at: start, title: "Membership meeting",
      location_name: "Community Hall", location_address: "50 Lake Road\nTwo Rivers, WI")
    system_sign_in(member)

    Dir.mktmpdir do |downloads|
      page.driver.browser.execute_cdp("Browser.setDownloadBehavior", behavior: "allow", downloadPath: downloads)
      [ [ 1280, 900 ], [ 561, 900 ], [ 390, 844 ], [ 320, 800 ] ].each do |width, height|
        page.current_window.resize_to(width, height)
        visit calendar_path(start_date: start.to_date, display: "schedule")
        find(".calendar-schedule-event", text: event.title).click
        check_calendar_choices(event, width, downloads)

        visit meetings_path
        click_link meeting.title
        check_calendar_choices(meeting, width, downloads)
      end
    end
  ensure
    page.driver.browser.execute_cdp("Browser.setDownloadBehavior", behavior: "default")
    page.current_window.resize_to(1400, 1000)
  end

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
      find(".calendar-month-heading").scroll_to(:top)
      capture_system_screenshot("calendar-schedule-#{width}")
      first(".calendar-schedule-event").send_keys(:tab)
      assert_selector ".calendar-schedule-event:focus-visible"
      find(".calendar-schedule-event", text: "Community car and bike show").click
      assert_current_path calendar_event_path(events.first)
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  private

  def check_calendar_choices(entry, width, downloads)
    assert_current_path polymorphic_path(entry)
    assert_no_link "Apple Calendar", wait: 0
    summary = find("summary", exact_text: "Add to calendar")
    place = find_link("View on map")
    assert_equal "Add to calendar", summary.native.accessible_name
    assert_includes place.native.accessible_name, entry.is_a?(Meeting) ? entry.location_name : entry.location
    assert_includes place.native.accessible_name, "View on map"
    [ summary.find("span", exact_text: "Add to calendar"), place.find("span", exact_text: "View on map", match: :first) ].each do |label|
      assert_operator label.native.size.width, :>=, 80
      assert_operator label.native.size.height, :>=, 16
    end
    [ summary, place ].each do |control|
      assert_operator control.native.size.width, :>=, 44
      assert_operator control.native.size.height, :>=, 44
    end
    assert_calendar_actions_aligned(summary, place)
    capture_system_screenshot("member-calendar-#{entry.model_name.singular}-#{width}")
    summary.send_keys(:enter)
    assert_selector "summary:focus-visible"
    apple = find_link("Apple Calendar iPhone or iPad")
    google = find_link("Google Calendar Android or Google account")
    [ apple, google ].each do |choice|
      assert_operator choice.native.size.height, :>=, 44
      assert_operator choice.find("small").style("font-size")["font-size"].to_f, :>=, 14
    end
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    assert_calendar_actions_aligned(summary, place)
    capture_system_screenshot("member-calendar-#{entry.model_name.singular}-#{width}-expanded")

    apple.click
    file = File.join(downloads, "#{entry.model_name.singular}-#{entry.id}.ics")
    Timeout.timeout(5) { sleep 0.05 until File.exist?(file) }
    saved = Icalendar::Calendar.parse(File.read(file)).sole.events.sole
    assert_equal entry.title, saved.summary.to_s
    assert_equal polymorphic_path(entry), URI(saved.url.to_s).path
    File.delete(file)

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_no_selector ".member-calendar-choices, .member-calendar-place .member-calendar-action", wait: 0
    assert_text entry.is_a?(Meeting) ? entry.location_address.lines.first.strip : entry.location
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
  end

  def assert_calendar_actions_aligned(summary, place)
    map_action = place.find(".member-calendar-action")
    %w[svg span].each do |selector|
      assert_in_delta summary.find(selector).native.rect.x, map_action.find(selector).native.rect.x, 1,
        "The calendar and map #{selector} should start on the same vertical line"
    end
  end
end
