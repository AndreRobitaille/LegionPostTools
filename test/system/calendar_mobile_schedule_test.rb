require "application_system_test_case"

class CalendarMobileScheduleTest < ApplicationSystemTestCase
  test "members can save a single calendar entry and open the device map from event and meeting pages" do
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

    chrome = page.driver.browser
    original_agent = page.evaluate_script("navigator.userAgent")
    mac = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/605.1.15 Version/18.3 Safari/605.1.15"
    Dir.mktmpdir do |downloads|
      page.driver.browser.execute_cdp("Browser.setDownloadBehavior", behavior: "allow", downloadPath: downloads)
      [
        [ 1280, 900, mac, false, :desktop ],
        [ 561, 900, "Mozilla/5.0 (Windows NT 10.0; Win64; x64)", true, :desktop ],
        [ 1024, 768, mac, true, :ios ],
        [ 390, 844, "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X)", true, :ios ],
        [ 320, 800, "Mozilla/5.0 (Linux; Android 15)", true, :android ]
      ].each do |width, height, agent, touch, expected|
        chrome.execute_cdp("Network.setUserAgentOverride", userAgent: agent)
        chrome.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: touch, maxTouchPoints: 5)
        page.current_window.resize_to(width, height)
        visit calendar_path(start_date: start.to_date, display: "schedule")
        find(".calendar-schedule-event", text: event.title).click
        check_calendar_links(event, width, expected, downloads)

        visit meetings_path
        click_link meeting.title
        check_calendar_links(meeting, width, expected, downloads)
      end
    end
    Capybara.reset_sessions!
    [ event, meeting ].each do |entry|
      visit polymorphic_path(entry, format: :ics)
      assert_current_path new_session_path
      assert_button "Send my sign-in email"
    end
  ensure
    chrome.execute_cdp("Network.setUserAgentOverride", userAgent: original_agent) if original_agent
    chrome.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    chrome.execute_cdp("Browser.setDownloadBehavior", behavior: "default")
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

  def check_calendar_links(entry, width, device, downloads)
    assert_current_path polymorphic_path(entry)
    assert_no_link "Apple Calendar", wait: 0
    selector = device == :desktop ? "summary" : "a"
    action = find(selector, exact_text: "Add to calendar")
    assert_selector ".member-calendar-direct, .member-calendar-choices summary", count: 1
    assert_selector "a.member-calendar-place", count: 1
    place = find_link("View on map")
    location = entry.is_a?(Meeting) ? entry.location_address.squish : entry.location
    query = ERB::Util.url_encode(location)
    destination = { desktop: "https://www.google.com/maps/search/?api=1&query=", ios: "https://maps.apple.com/?q=", android: "geo:0,0?q=" }
    assert_equal destination.fetch(device) + query, place[:href]
    assert_equal "Add to calendar", action.native.accessible_name
    assert_includes place.native.accessible_name, entry.is_a?(Meeting) ? entry.location_name : entry.location
    [ action, place.find(".member-calendar-action") ].each do |control|
      assert_operator control.find("span").native.size.width, :>=, 80
      assert_operator control.find("span").native.size.height, :>=, 16
      assert_operator control.native.size.width, :>=, 44
      assert_operator control.native.size.height, :>=, 44
      assert_tappable(control)
    end
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    assert_calendar_actions_aligned(action, place)
    capture_system_screenshot("member-calendar-#{entry.model_name.singular}-#{width}")
    file_link = action
    if device == :desktop
      action.send_keys(:enter)
      assert_selector "summary:focus-visible"
      file_link = find_link("Apple Calendar")
      google = find_link("Google Calendar")
      [ file_link, google ].each do |choice|
        assert_operator choice.native.size.height, :>=, 44
        assert_operator choice.find("small").style("font-size")["font-size"].to_f, :>=, 14
        assert_tappable(choice)
      end
      assert_text "If your Mac saves the .ics file, open it in Calendar."
      assert_operator place.native.rect.y, :>=, google.native.rect.y + google.native.size.height
      assert_calendar_actions_aligned(action, place)
      capture_system_screenshot("member-calendar-#{entry.model_name.singular}-#{width}-expanded")
    else
      assert_no_selector "details.member-calendar-choices"
      assert_no_link "Google Calendar"
    end
    file_link.click
    file = File.join(downloads, "#{entry.model_name.singular}-#{entry.id}.ics")
    Timeout.timeout(5) { sleep 0.05 until File.exist?(file) }
    saved = Icalendar::Calendar.parse(File.read(file)).sole.events.sole
    assert_equal entry.title, saved.summary.to_s
    assert_equal polymorphic_path(entry), URI(saved.url.to_s).path
    File.delete(file)

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_no_selector ".member-calendar-choices, .member-calendar-direct, .member-calendar-place .member-calendar-action", wait: 0
    assert_text entry.is_a?(Meeting) ? entry.location_address.lines.first.strip : entry.location
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
  end

  def assert_tappable(link)
    link.execute_script("this.scrollIntoView({ block: 'center' })")
    assert link.evaluate_script(<<~JS), "An overlapping element covers part of #{link.text}"
      (() => {
        const box = this.getBoundingClientRect()
        return [box.top + 3, box.top + box.height / 2, box.bottom - 3].every(y =>
          this.contains(document.elementFromPoint(box.left + box.width / 2, y)))
      })()
    JS
  end

  def assert_calendar_actions_aligned(summary, place)
    map_action = place.find(".member-calendar-action")
    %w[svg span].each do |selector|
      assert_in_delta summary.find(selector).native.rect.x, map_action.find(selector).native.rect.x, 1,
        "The calendar and map #{selector} should start on the same vertical line"
    end
  end
end
