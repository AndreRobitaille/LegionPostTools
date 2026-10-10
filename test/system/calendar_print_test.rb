require "application_system_test_case"
require "base64"

class CalendarPrintTest < ApplicationSystemTestCase
  LONG_TITLE = "Joint picnic planning meeting with the Auxiliary for the park shelter reservation and setup crew".freeze
  LONG_LOCATION = "Post home meeting room, 400 Legion Park Road".freeze

  setup do
    page.current_window.resize_to(1400, 1000)
    @organization = Organization.create!(
      name: "Robert E. Burns American Legion Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @member = User.create!(person: Person.create!(first_name: "Print", last_name: "Officer"), email_address: "print-officer@example.com")
    zone = @organization.calendar_time_zone
    events = [
      [ LONG_TITLE, "planning_meeting", 8, 18, LONG_LOCATION, false ],
      [ "Membership meeting and new member welcome", "member_meeting", 1, 19, "Post home", false ],
      [ "Honor Guard practice at the memorial", "honor_guard", 1, 17, "Memorial flagpole", false ],
      [ "Officers planning session for the fall calendar", "officer_meeting", 3, 18, "Post home conference room", false ],
      [ "Community breakfast", "other", 5, 8, "Post hall", false ],
      [ "Public car and bike show briefing", "public_event", 6, nil, "Legion park shelter", true ],
      [ "Festival planning meeting", "planning_meeting", 8, 19, LONG_LOCATION, false ],
      [ "Honor Guard funeral detail", "honor_guard", 8, 10, "Local cemetery chapel", false ],
      [ "Auxiliary dinner coordination", "other", 8, 16, "Post kitchen", false ],
      [ "Membership meeting follow-up on the scholarship fund", "member_meeting", 12, 19, "Post home", false ],
      [ "Blood drive setup", "public_event", 15, 9, "Post hall lobby", false ],
      [ "Color guard exhibition", "honor_guard", 16, 13, "High school gym", false ],
      [ "Post picnic and family open house", "public_event", 19, nil, "Lakefront park pavilion", true ],
      [ "Executive committee working session", "officer_meeting", 22, 18, "Post home conference room", false ],
      [ "Planning meeting for the Veterans Day program", "planning_meeting", 24, 18, LONG_LOCATION, false ],
      [ "Honor Guard uniform inspection", "honor_guard", 26, 9, "Post home", false ],
      [ "End of month officers roundtable", "officer_meeting", 29, 18, "Post home conference room", false ]
    ]
    events.each do |title, category, day, hour, location, all_day|
      starts_at = all_day ? zone.local(2026, 9, day) : zone.local(2026, 9, day, hour)
      @organization.calendar_events.create!(
        title: title, calendar_category: category, location: location, all_day: all_day,
        starts_at: starts_at, created_by: @member, updated_by: @member,
        cancelled: title == "Color guard exhibition"
      )
    end
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    page.current_window.resize_to(1400, 1000)
  end

  test "prints the month on one landscape page and the schedule as a readable list" do
    system_sign_in(@member)
    visit calendar_path(start_date: "2026-09-01")
    assert_selector ".app-header"
    assert_selector ".nav-bar"
    assert_selector ".calendar-filters"
    assert_selector ".calendar-footer"
    assert_button "Print"
    assert_selector ".calendar-grid-event", text: LONG_TITLE
    assert_no_selector ".calendar-block-location", text: LONG_LOCATION
    capture_system_screenshot("calendar-screen-month")
    page.execute_script("window.__printCalls = 0; window.print = () => { window.__printCalls += 1 }")
    click_button "Print"
    assert_equal 1, page.evaluate_script("window.__printCalls")

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_selector ".calendar-print-heading", text: "Robert E. Burns American Legion Post 165"
    assert_selector ".calendar-print-heading", text: "September 2026"
    assert_no_selector ".app-header"
    assert_no_selector ".nav-bar"
    assert_no_selector ".calendar-filters"
    assert_no_selector ".calendar-footer"
    assert_no_selector "button", text: "Print"
    assert_no_selector ".calendar-schedule"
    assert_selector ".calendar-grid-event", text: LONG_TITLE
    assert_selector ".calendar-block-location", text: LONG_LOCATION
    assert_selector ".calendar-block-time", text: "18:00"
    title = find(".calendar-block-title", text: LONG_TITLE)
    assert_equal "none", title.style("-webkit-line-clamp")["-webkit-line-clamp"]
    assert_equal LONG_TITLE, title.text
    assert_not title.evaluate_script("this.scrollHeight > this.clientHeight + 1")
    event = find(".calendar-grid-event", text: LONG_TITLE)
    assert_includes event.style("color")["color"], "0, 0, 0"
    assert_includes event.style("background-color")["background-color"], "255, 255, 255"
    outside = find(".calendar-grid .next-month .calendar-day-number", match: :first)
    assert_includes outside.style("color")["color"], "118, 118, 118"
    assert_equal "400", outside.style("font-weight")["font-weight"]
    cancelled = find(".calendar-grid-event", text: "Color guard exhibition")
    assert_equal "line-through", cancelled.find(".calendar-block-title").style("text-decoration-line")["text-decoration-line"]
    assert_equal "dashed", cancelled.style("border-top-style")["border-top-style"]
    assert_selector ".calendar-grid-status", text: "Cancelled"
    assert_no_selector ".calendar-print-filters"
    assert_match(/\d{2} [A-Z]{3} \d{4}/, page.evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--calendar-printed-on')"))
    assert_equal 1, printed_page_count
    assert_match(/792(?:\.0)? 612(?:\.0)?/, printed_media_box)

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    uncheck "Officer Meeting"
    uncheck "Public events"
    uncheck "Other activities"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_selector ".calendar-print-filters", text: "Showing: Member Meeting, Planning meetings, Honor Guard"
    assert_selector ".calendar-grid-event", text: "Color guard exhibition"
    assert_selector ".calendar-grid .next-month .calendar-day-number", text: "1"
    assert_no_selector ".calendar-grid-event", text: "Community breakfast"
    grid = find(".calendar-grid")
    assert_equal "border-box", grid.style("box-sizing")["box-sizing"]
    assert_not grid.evaluate_script("this.getBoundingClientRect().right > this.parentElement.getBoundingClientRect().right + 0.75 || this.getBoundingClientRect().left < this.parentElement.getBoundingClientRect().left - 0.75")
    save_print_preview("calendar-print-filtered")
    assert_equal 1, printed_page_count

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    assert_selector ".app-header"
    assert_selector ".calendar-filters"
    assert_selector ".calendar-grid"
    click_button "Schedule"
    assert_selector ".calendar-schedule-event", text: LONG_TITLE
    assert_selector ".calendar-event-place", text: LONG_LOCATION
    assert_no_selector ".calendar-grid"

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_selector ".calendar-print-heading", text: "September 2026"
    assert_no_selector ".calendar-grid"
    assert_no_selector ".calendar-filters"
    assert_no_selector ".calendar-schedule-action"
    assert_selector ".calendar-schedule-event", text: LONG_TITLE
    assert_selector ".calendar-event-place", text: LONG_LOCATION
    schedule_title = find(".calendar-schedule-event h4", text: LONG_TITLE)
    assert_not schedule_title.evaluate_script("this.scrollHeight > this.clientHeight + 1")
    assert_equal "line-through", find(".calendar-schedule-event h4", text: "Color guard exhibition").style("text-decoration-line")["text-decoration-line"]
    assert_selector ".calendar-print-filters", text: "Showing: Member Meeting, Planning meetings, Honor Guard"
    assert_includes find(".calendar-date-group", match: :first).style("border-bottom-color")["border-bottom-color"], "187, 187, 187"
    capture_system_screenshot("calendar-print-schedule")
    save_print_preview("calendar-print-schedule")
  end

  test "a six-week month prints on one landscape page" do
    zone = @organization.calendar_time_zone
    [
      [ 1, "May membership meeting and scholarship report" ],
      [ 8, "Honor Guard memorial detail" ],
      [ 15, "Planning meeting for the Memorial Day program at the park" ],
      [ 22, "Officers roundtable" ],
      [ 29, "Community breakfast" ]
    ].each do |day, title|
      @organization.calendar_events.create!(
        title: title, calendar_category: "other", location: "Post home",
        starts_at: zone.local(2027, 5, day, 18), created_by: @member, updated_by: @member
      )
    end
    system_sign_in(@member)
    visit calendar_path(start_date: "2027-05-01")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_selector ".calendar-print-heading", text: "May 2027"
    assert_selector ".calendar-grid tbody tr", count: 6
    assert_selector ".calendar-grid .next-month .calendar-day-number", text: "1"
    save_print_preview("calendar-print-may-2027")
    assert_equal 1, printed_page_count
    assert_match(/792(?:\.0)? 612(?:\.0)?/, printed_media_box)
  end

  private

  def printed_pdf
    Base64.decode64(page.driver.browser.execute_cdp("Page.printToPDF", printBackground: false, preferCSSPageSize: true, displayHeaderFooter: false).fetch("data"))
  end

  def save_print_preview(name)
    return if ENV["SYSTEM_TEST_CAPTURE_DIR"].blank?

    File.binwrite(Rails.root.join(ENV["SYSTEM_TEST_CAPTURE_DIR"], "#{name}.pdf"), printed_pdf)
  end

  def printed_page_count
    printed_pdf.scan(%r{/Type\s*/Page(?!s)}).size
  end

  def printed_media_box
    printed_pdf[/MediaBox\s*\[\s*[^\]]+\]/]
  end
end
