require "application_system_test_case"
require "base64"

class CalendarPrintTest < ApplicationSystemTestCase
  LONG_TITLE = "Joint picnic planning meeting with the Auxiliary for the park shelter reservation and setup crew".freeze
  LONG_LOCATION = "Post home meeting room, 400 Legion Park Road".freeze
  DESCRIPTION = "Review the shelter reservation, meal plan, and volunteer assignments with the Auxiliary.\nBring the current setup checklist.\n\nSetup volunteers should meet at the north entrance; please bring work gloves.".freeze

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
      [ "Membership meeting follow-up on the scholarship fund", "member_meeting", 12, 19, "", false ],
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
      event = @organization.calendar_events.create!(
        title: title, calendar_category: category, location: location, all_day: all_day,
        starts_at: starts_at, created_by: @member, updated_by: @member,
        cancelled: title == "Color guard exhibition"
      )
      if title == LONG_TITLE
        event.update!(ends_at: zone.local(2026, 9, day, 19, 30), description: DESCRIPTION)
      elsif title == "Honor Guard practice at the memorial"
        event.update!(description: "Meet at the flagpole 15 minutes early. Bring your uniform and white gloves.\n\nWe will review the formation and practice the flag presentation before the ceremony.")
      end
    end
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    page.current_window.resize_to(1400, 1000)
  end

  test "prints the month and detailed schedule together with the selected filters" do
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
    assert_selector ".calendar-schedule"
    assert_selector ".calendar-grid-event", text: LONG_TITLE
    assert_no_selector ".calendar-block-location"
    assert_no_selector ".calendar-grid .calendar-print-description"
    assert_no_selector ".calendar-block-time"
    assert_selector ".calendar-block-print-time", exact_text: "18:00"
    assert_no_selector ".calendar-block-print-time", text: "19:30"
    title = find(".calendar-block-title", text: LONG_TITLE)
    assert_equal "none", title.style("-webkit-line-clamp")["-webkit-line-clamp"]
    assert_equal LONG_TITLE, title.text
    assert_operator title.style("font-size")["font-size"].to_f, :>=, 14.5
    assert_equal "400", title.style("font-weight")["font-weight"]
    assert_operator find(".calendar-block-print-time", match: :first).style("font-size")["font-size"].to_f, :>=, 14
    assert_not title.evaluate_script("this.scrollHeight > this.clientHeight + 1")
    event = find(".calendar-grid-event", text: LONG_TITLE)
    assert_includes event.style("color")["color"], "0, 0, 0"
    assert_includes event.style("background-color")["background-color"], "255, 255, 255"
    outside = find(".calendar-grid .next-month .calendar-day-number", match: :first)
    assert_includes outside.style("color")["color"], "118, 118, 118"
    assert_equal "400", outside.style("font-weight")["font-weight"]
    cancelled = find(".calendar-grid-event", text: "Color guard exhibition")
    assert_equal "line-through", cancelled.find(".calendar-block-title").style("text-decoration-line")["text-decoration-line"]
    assert_equal "0px", event.style("border-left-width")["border-left-width"]
    assert_selector ".calendar-grid-status", text: "Cancelled"
    assert_no_selector ".calendar-print-filters"
    assert_equal [ 792, 612 ], printed_page_sizes.first
    assert_equal [ 612, 792 ], printed_page_sizes.last
    save_print_preview("calendar-month-and-schedule")

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    uncheck "Officer Meeting"
    uncheck "Public events"
    uncheck "Other activities"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_no_selector ".calendar-print-filters"
    assert_selector ".calendar-grid-event", text: "Color guard exhibition"
    assert_selector ".calendar-grid .next-month .calendar-day-number", text: "1"
    assert_no_selector ".calendar-grid-event", text: "Community breakfast"
    assert_no_selector ".calendar-schedule-event", text: "Community breakfast"
    grid = find(".calendar-grid")
    assert_equal "border-box", grid.style("box-sizing")["box-sizing"]
    assert_not grid.evaluate_script("this.getBoundingClientRect().right > this.parentElement.getBoundingClientRect().right + 0.75 || this.getBoundingClientRect().left < this.parentElement.getBoundingClientRect().left - 0.75")
    save_print_preview("calendar-print-filtered")

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    assert_selector ".app-header"
    assert_selector ".calendar-filters"
    assert_selector ".calendar-grid"
    click_button "Schedule"
    assert_selector ".calendar-schedule-event", text: LONG_TITLE
    assert_selector ".calendar-event-place", text: LONG_LOCATION
    assert_no_selector ".calendar-print-description"
    assert_no_selector ".calendar-grid"

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_selector ".calendar-print-heading", text: "September 2026"
    assert_selector ".calendar-grid"
    assert_no_selector ".calendar-filters"
    assert_no_selector ".calendar-schedule-action"
    assert_selector ".calendar-schedule-event", text: LONG_TITLE
    assert_selector ".calendar-event-place", text: LONG_LOCATION
    detailed_event = find(".calendar-schedule-event", text: LONG_TITLE)
    assert_selector ".calendar-schedule-event", text: "18:00–19:30"
    assert_equal DESCRIPTION.split("\n\n"), detailed_event.all(".calendar-print-description p").map(&:text)
    assert_selector ".calendar-print-description", text: "Setup volunteers should meet at the north entrance"
    assert_operator detailed_event.find(".calendar-print-description p", match: :first).style("font-size")["font-size"].to_f, :>=, 16
    columns = detailed_event.evaluate_script("[...this.querySelectorAll('.calendar-schedule-identity, .calendar-schedule-detail')].map(element => { const box = element.getBoundingClientRect(); return { left: box.left, right: box.right, top: box.top } })")
    assert_operator columns[1].fetch("left"), :>=, columns[0].fetch("right") - 1
    assert_in_delta columns[0].fetch("top"), columns[1].fetch("top"), 1
    assert_not detailed_event.evaluate_script("this.scrollWidth > this.clientWidth + 1")
    simple_event = find(".calendar-schedule-event", text: "Membership meeting follow-up on the scholarship fund")
    assert_no_selector ".calendar-schedule-event", text: "Showing:"
    assert_equal "none", simple_event.find(".calendar-schedule-identity").style("float")["float"]
    assert_not simple_event.has_css?(".calendar-schedule-detail")
    schedule_title = find(".calendar-schedule-event h4", text: LONG_TITLE)
    assert_not schedule_title.evaluate_script("this.scrollHeight > this.clientHeight + 1")
    assert_equal "line-through", find(".calendar-schedule-event h4", text: "Color guard exhibition").style("text-decoration-line")["text-decoration-line"]
    assert_no_selector ".calendar-print-filters"
    assert_equal "0px", detailed_event.style("border-left-width")["border-left-width"]
    assert_no_selector ".calendar-schedule-event svg"
    capture_system_screenshot("calendar-print-schedule")
    save_print_preview("calendar-print-schedule")
  end

  test "a six-week month prints on one landscape page followed by the portrait schedule" do
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
    assert_no_selector ".calendar-block-location"
    assert_no_selector ".calendar-grid .calendar-print-description"
    save_print_preview("calendar-print-may-2027")
    assert_equal [ [ 792, 612 ], [ 612, 792 ] ], printed_page_sizes
  end

  test "printing from a phone includes both layouts without changing the selected view" do
    system_sign_in(@member)
    visit calendar_path(start_date: "2026-09-01")
    uncheck "Other activities"
    screen_url = page.current_url

    [ 390, 320 ].each do |width|
      page.current_window.resize_to(width, 844)
      assert_no_selector ".calendar-grid"
      assert_selector ".calendar-schedule-event", text: LONG_TITLE
      capture_system_screenshot("calendar-screen-phone-#{width}")

      # Page.printToPDF uses the actual paper width, rather than merely
      # emulating print styles inside the phone viewport.
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
      assert_no_selector ".app-header"
      assert_no_selector ".calendar-filters"
      assert_selector ".calendar-grid"
      assert_selector ".calendar-schedule-event", text: LONG_TITLE
      sizes = printed_page_sizes
      assert_equal [ 792, 612 ], sizes.first
      first_schedule_page = sizes.index([ 612, 792 ])
      assert first_schedule_page, "the month must be followed by a portrait schedule"
      assert sizes.drop(first_schedule_page).all? { |size| size == [ 612, 792 ] }
      save_print_preview("calendar-print-phone-#{width}")
      assert_no_selector ".calendar-print-filters"
      assert_selector ".calendar-print-description", text: "Bring the current setup checklist."
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")

      assert_equal screen_url, page.current_url
      assert_selector ".calendar-workspace[data-calendar-display-value='month']"
      assert_unchecked_field "Other activities"
      assert_no_selector ".calendar-grid"
    end

    page.current_window.resize_to(1400, 1000)
    assert_selector ".calendar-grid"
    assert_no_selector ".calendar-schedule"
  end

  test "printing and cancelling preserve either selected screen view and its filters" do
    system_sign_in(@member)
    visit calendar_path(start_date: "2026-09-01")
    uncheck "Other activities"

    %w[Month Schedule].each do |view|
      click_button view
      screen_url = page.current_url
      page.execute_script("window.dispatchEvent(new Event('beforeprint'))")
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
      assert_selector ".calendar-grid"
      assert_selector ".calendar-schedule"
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
      page.execute_script("window.dispatchEvent(new Event('afterprint'))")

      assert_equal screen_url, page.current_url
      assert_selector ".calendar-workspace[data-calendar-display-value='#{view.downcase}']"
      assert_selector "button[aria-pressed='true']", text: view
      assert_unchecked_field "Other activities"
      assert_no_selector(view == "Month" ? ".calendar-schedule" : ".calendar-grid")
    end
  end

  test "printed dates do not highlight the current day" do
    travel_to(@organization.calendar_time_zone.local(2026, 9, 8, 12)) do
      system_sign_in(@member)
      visit calendar_path(start_date: "2026-09-01")
      today = find(".calendar-grid [aria-current='date'] .calendar-day-number")
      assert_equal "50%", today.style("border-radius")["border-radius"]
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
      ordinary_day = find(".calendar-grid td:not(.today):not(.prev-month):not(.next-month) .calendar-day-number", match: :first)
      properties = %w[background-color border-width border-radius color font-weight]
      assert_equal ordinary_day.style(*properties), today.style(*properties)
      assert_equal "0px", today.style("border-width")["border-width"]
      save_print_preview("calendar-print-without-today-marker")
    end
  end

  test "an empty selection prints one month page and an empty schedule without a trailing page" do
    system_sign_in(@member)
    visit calendar_path(start_date: "2026-09-01", categories: [ "" ])
    assert_text "No events to show"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_selector ".calendar-print-empty", text: "No events to show for this month."
    assert_no_selector ".calendar-grid-event"
    assert_no_selector ".calendar-schedule-event"
    assert_equal [ [ 792, 612 ], [ 612, 792 ] ], printed_page_sizes
    save_print_preview("calendar-print-empty")
  end

  test "crowded days continue onto additional pages without shrinking the chosen print size" do
    zone = @organization.calendar_time_zone
    12.times do |index|
      @organization.calendar_events.create!(
        title: "Activity #{index + 1}: #{LONG_TITLE}", calendar_category: "other",
        location: "Post home " + "meeting room and park shelter directions " * 10,
        starts_at: zone.local(2026, 9, 9, 18), created_by: @member, updated_by: @member
      )
    end
    system_sign_in(@member)
    visit calendar_path(start_date: "2026-09-01")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_selector ".calendar-grid-event", text: "Activity 12: #{LONG_TITLE}"
    assert_selector ".calendar-schedule"
    titles = all(".calendar-block-title")
    assert titles.all? { |title| title.style("font-size")["font-size"].to_f >= 14.5 }
    assert titles.none? { |title| title.evaluate_script("this.scrollHeight > this.clientHeight + 1 || this.scrollWidth > this.clientWidth + 1") }
    assert_equal "table-header-group", find(".calendar-grid thead").style("display")["display"]
    sizes = printed_page_sizes
    assert_operator sizes.count([ 792, 612 ]), :>, 1
    assert_equal [ 612, 792 ], sizes.last
    save_print_preview("calendar-print-crowded")
  end

  test "printed schedule includes the saved meeting address" do
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    create_meeting!(organization: @organization, meeting_body: body,
      starts_at: @organization.calendar_time_zone.local(2026, 9, 17, 19),
      title: "Membership meeting", location_name: "Post hall", location_address: "400 Legion Park Road")
    system_sign_in(@member)
    visit calendar_path(start_date: "2026-09-01", display: "schedule")
    assert_no_selector ".calendar-print-address"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_selector ".calendar-event-place", text: "Post hall, 400 Legion Park Road"
  end

  test "long schedule descriptions continue onto later pages without clipping" do
    description = ((1..30).map { |number| "Preparation step #{number}: Review the volunteer assignments, confirm the supplies, and check the meeting room and park shelter arrangements." } + [ "Final instruction: Return the checklist to the Adjutant." ]).join("\n\n")
    @organization.calendar_events.find_by!(title: LONG_TITLE).update!(description: description)
    system_sign_in(@member)
    visit calendar_path(start_date: "2026-09-01", display: "schedule", categories: [ "planning_meeting" ])
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    event = find(".calendar-schedule-event", text: LONG_TITLE)
    assert_equal "auto", event.style("break-inside")["break-inside"]
    assert_equal "8", event.find(".calendar-print-event-date strong").text
    within find(".calendar-schedule-event", text: "Festival planning meeting") do
      assert_no_selector ".calendar-print-event-date"
    end
    assert_selector ".calendar-print-description", text: "Preparation step 1:"
    assert_selector ".calendar-print-description", text: "Final instruction: Return the checklist to the Adjutant."
    assert_equal 31, event.all(".calendar-print-description p").size
    schedule_pages = printed_page_sizes.count([ 612, 792 ])
    assert_operator schedule_pages, :>, 1
    assert_operator schedule_pages, :<=, 3, "the continued description should not create a heading-only page"
    save_print_preview("calendar-print-long-description")
  end

  test "one long paragraph flows across pages without forcing a heading-only sheet" do
    description = (1..30).map { |number| "Preparation step #{number}: Review the volunteer assignments, confirm the supplies, and check the meeting room and park shelter arrangements." }.join(" ")
    description += " Final instruction: Return the checklist to the Adjutant."
    @organization.calendar_events.find_by!(title: LONG_TITLE).update!(description: description)
    system_sign_in(@member)
    visit calendar_path(start_date: "2026-09-01", display: "schedule", categories: [ "planning_meeting" ])
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    event = find(".calendar-schedule-event", text: LONG_TITLE)
    assert_equal description, event.find(".calendar-print-description p").text
    assert_operator printed_page_sizes.count([ 612, 792 ]), :<=, 3
    save_print_preview("calendar-print-long-paragraph")
  end

  private

  def printed_pdf
    Base64.decode64(page.driver.browser.execute_cdp("Page.printToPDF", printBackground: false, preferCSSPageSize: true, displayHeaderFooter: false).fetch("data"))
  end

  def save_print_preview(name)
    return if ENV["SYSTEM_TEST_CAPTURE_DIR"].blank?

    directory = Rails.root.join(ENV.fetch("SYSTEM_TEST_CAPTURE_DIR"))
    FileUtils.mkdir_p(directory)
    File.binwrite(directory.join("#{name}.pdf"), printed_pdf)
  end

  def printed_page_sizes
    printed_pdf.scan(/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]/).map do |width, height|
      [ width.to_f.round, height.to_f.round ]
    end
  end
end
