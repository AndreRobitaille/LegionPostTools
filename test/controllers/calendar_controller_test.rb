require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @member = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Member"), email_address: "calendar-member@example.com")
    @manager = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Admin"), email_address: "calendar-admin@example.com")
    @manager.permission_grants.create!(capability: "manage_settings")
    @event = @organization.calendar_events.create!(title: "Community breakfast", starts_at: Time.zone.local(2026, 9, 12, 9), created_by: @manager, updated_by: @manager)
  end

  test "calendar and events require sign in" do
    [ calendar_path, manage_calendar_path, calendar_event_path(@event), new_calendar_event_path ].each do |path|
      get path
      assert_redirected_to new_session_path
    end
  end

  test "members see meetings and events with top level navigation but no management controls" do
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: @event.starts_at, title: "Membership meeting")
    sign_in_as(@member)
    get calendar_path(start_date: "2026-09-01")
    assert_response :success
    assert_select "a[href=?]", meeting_path(meeting), minimum: 1
    assert_select "a[href=?]", calendar_event_path(@event), minimum: 1
    assert_select ".nav-tab--active", text: "Calendar"
    assert_select "a[href*='/calendar/manage']", count: 0
    assert_select ".calendar-grid th", count: 7
    get calendar_event_path(@event)
    assert_response :success
    assert_select "h1", text: "Community breakfast"
    assert_select ".calendar-event-heading .calendar-event-type", text: "Other activities"
    assert_select ".calendar-event-timezone", text: "Times in America/Chicago"
    assert_select "dt", text: "Time zone", count: 0
    @event.update!(all_day: true)
    get calendar_event_path(@event)
    assert_select ".calendar-event-timezone", count: 0
    assert_select "a[href=?]", edit_calendar_event_path(@event), count: 0
  end

  test "members and agenda delegates cannot mutate calendar events" do
    @member.permission_grants.create!(capability: "manage_agendas")
    @member.permission_grants.create!(capability: "approve_minutes")
    sign_in_as(@member)
    get manage_calendar_path
    assert_redirected_to root_path
    get edit_calendar_event_path(@event)
    assert_redirected_to root_path
    assert_no_difference "CalendarEvent.count" do
      post calendar_events_path, params: { calendar_event: event_params }
      assert_redirected_to root_path
    end
    patch calendar_event_path(@event), params: { calendar_event: event_params.merge(title: "Changed") }
    assert_redirected_to root_path
    assert_equal "Community breakfast", @event.reload.title
  end

  test "current commander and adjutant office assignments grant management and expiry removes it" do
    %w[approve_minutes attest_minutes].each do |capability|
      office = @organization.position_titles.create!(name: capability, display_order: 1)
      office.position_capability_grants.create!(capability: capability)
      assignment = office.position_assignments.create!(person: @member.person, starts_on: Date.current - 2.days)
      sign_in_as(@member)
      get manage_calendar_path(start_date: "2026-09-01")
      assert_response :success
      assert_select "a[href=?]", new_calendar_event_path
      assignment.update!(ends_on: Date.yesterday)
      get manage_calendar_path
      assert_redirected_to root_path
    end
  end

  test "admin creates public linked event and edits or cancels it with provenance" do
    endeavor = @organization.endeavors.create!(title: "Community meals", created_by: @manager)
    sign_in_as(@manager)
    get new_calendar_event_path(endeavor_id: endeavor.id)
    assert_response :success
    assert_select "option[selected][value=?]", endeavor.id.to_s
    assert_difference "CalendarEvent.count", 1 do
      post calendar_events_path, params: { calendar_event: event_params.merge(endeavor_id: endeavor.id, visibility: "public") }
    end
    event = CalendarEvent.order(:id).last
    assert_redirected_to calendar_event_path(event)
    assert_equal @manager, event.created_by
    assert_equal @manager, event.updated_by
    assert event.public?
    assert_equal endeavor, event.endeavor
    get edit_calendar_event_path(event)
    assert_response :success
    patch calendar_event_path(event), params: { calendar_event: event_params.merge(cancelled: "1", lock_version: event.lock_version) }
    assert_redirected_to calendar_event_path(event)
    assert event.reload.cancelled?
    get calendar_event_path(event)
    assert_select "[role=status]", text: "This event is cancelled."
  end

  test "all day dates include the last day and need no time" do
    sign_in_as(@manager)
    post calendar_events_path, params: { calendar_event: event_params.merge(all_day: "1", starts_at_time: "", ends_at_date: "14 SEP 2026", ends_at_time: "") }
    event = CalendarEvent.order(:id).last
    assert_redirected_to calendar_event_path(event)
    assert_equal @organization.calendar_time_zone.local(2026, 9, 12), event.starts_at
    assert_equal Date.new(2026, 9, 14), event.ends_at.in_time_zone(@organization.calendar_time_zone).to_date
    assert_equal 23, event.ends_at.in_time_zone(@organization.calendar_time_zone).hour
    get edit_calendar_event_path(event)
    assert_response :success
  end

  test "invalid dates and end times remain visible with validation errors" do
    sign_in_as(@manager)
    [ { starts_at_date: "impossible" }, { ends_at_date: "13 SEP 2026", ends_at_time: "25:00" }, { ends_at_date: "11 SEP 2026", ends_at_time: "09:00" } ].each do |invalid|
      assert_no_difference "CalendarEvent.count" do
        post calendar_events_path, params: { calendar_event: event_params.merge(invalid) }
      end
      assert_response :unprocessable_entity
      assert_select ".error-summary"
    end
  end

  test "stale changes cannot overwrite an event" do
    sign_in_as(@manager)
    version = @event.lock_version
    @event.update!(title: "Updated elsewhere")
    patch calendar_event_path(@event), params: { calendar_event: event_params.merge(lock_version: version) }
    assert_redirected_to edit_calendar_event_path(@event)
    assert_equal "Updated elsewhere", @event.reload.title
  end

  test "events cannot link to an Endeavor in another organization" do
    other = Organization.create!(name: "Another Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    endeavor = other.endeavors.create!(title: "Other work", created_by: @manager)
    sign_in_as(@manager)
    assert_no_difference "CalendarEvent.count" do
      post calendar_events_path, params: { calendar_event: event_params.merge(endeavor_id: endeavor.id) }
    end
    assert_response :unprocessable_entity
  end

  test "invalid calendar month redirects safely" do
    sign_in_as(@member)
    get calendar_path(start_date: "nope")
    assert_redirected_to calendar_path
  end

  test "invalid management month redirects without rendering twice" do
    sign_in_as(@manager)
    get manage_calendar_path(start_date: "invalid")
    assert_redirected_to calendar_path
  end

  test "due dates are optional on member calendar and absent from public preview" do
    project = @organization.endeavors.create!(title: "Internal newsletter", due_on: Date.new(2026, 9, 20), created_by: @manager)
    project.tasks.create!(title: "Collect confidential articles", due_on: Date.new(2026, 9, 18), created_by: @manager, updated_by: @manager)
    project.tasks.create!(title: "Undated step", created_by: @manager, updated_by: @manager)
    @event.update!(visibility: "public", endeavor: project, description: "Public breakfast description")
    sign_in_as(@member)
    get calendar_path(start_date: "2026-09-01")
    assert_select "h4", text: /Due:/, count: 0
    get calendar_path(start_date: "2026-09-01", view: "deadlines")
    assert_select "h4", text: "Due: Internal newsletter"
    assert_select "h4", text: "Due: Collect confidential articles"
    assert_select "h4", text: /Undated step/, count: 0
    get calendar_path(start_date: "2026-09-01", view: "public")
    assert_response :success
    assert_select "main", text: /Internal newsletter|Collect confidential articles|Undated step/, count: 0
    assert_select "a[href=?]", calendar_event_path(@event, preview: "public"), minimum: 1
    get calendar_event_path(@event, preview: "public")
    assert_response :success
    assert_select "main", text: /Public breakfast description/
    assert_select "main", text: /Internal newsletter/, count: 0
    @event.update!(visibility: "members")
    get calendar_event_path(@event, preview: "public")
    assert_response :not_found
  end

  test "Sunday weeks and multi-category filters retain selection in navigation" do
    @event.update!(calendar_category: "honor_guard", starts_at: Time.zone.local(2026, 8, 30, 8))
    volunteer = @organization.calendar_events.create!(title: "Volunteer setup", starts_at: Time.zone.local(2026, 9, 9, 8), created_by: @manager, updated_by: @manager)
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: Time.zone.local(2026, 9, 1, 19), title: "Membership Meeting — 01 SEP 2026")
    sign_in_as(@member)
    get calendar_path, params: { start_date: "2026-09-01", categories: %w[honor_guard planning_meeting] }
    assert_response :success
    assert_select ".calendar-grid th:first-child", text: "Sun"
    assert_select ".calendar-grid th:last-child", text: "Sat"
    assert_select "a[href=?]", calendar_event_path(@event), minimum: 1
    assert_select "a[href=?]", calendar_event_path(volunteer), minimum: 1
    assert_select ".calendar-grid-event[href=?]:not([hidden])", meeting_path(meeting), count: 0
    assert_select ".calendar-month-heading a[href*='honor_guard']", count: 3
    get calendar_path, params: { start_date: "2026-09-01", categories: [ "" ] }
    assert_select ".calendar-grid-event:not([hidden])", count: 0
    get calendar_path(start_date: "2026-09-01")
    assert_select ".calendar-grid-event", text: /Membership Meeting/, minimum: 1
    assert_select ".calendar-grid-event", text: /01 SEP 2026/, count: 0
    assert_equal "Membership Meeting — 01 SEP 2026", meeting.reload.title
  end

  test "event form accepts shorthand times and explicit categories" do
    sign_in_as(@manager)
    post calendar_events_path, params: { calendar_event: event_params.merge(starts_at_time: "800", calendar_category: "planning_meeting") }
    event = CalendarEvent.order(:id).last
    assert_redirected_to calendar_event_path(event)
    assert_equal 8, event.starts_at.in_time_zone(@organization.calendar_time_zone).hour
    assert_equal "planning_meeting", event.calendar_category
    get edit_calendar_event_path(event)
    assert_select "option[selected][value=planning_meeting]"
    assert_select "input[data-controller=time-field][pattern]", count: 0
  end

  test "calendar uses the Post zone even when the application zone is UTC" do
    sign_in_as(@manager)
    Time.use_zone("UTC") do
      @event.update!(starts_at: Time.utc(2026, 9, 2, 0, 30))
      get calendar_path(start_date: "2026-09-01")
      assert_select ".calendar-grid-event .calendar-block-time", text: "19:30"
      assert_select "h1", text: "Calendar", count: 0
      assert_equal "UTC", Time.zone.name
      [ [ "12 SEP 2026", 13 ], [ "12 DEC 2026", 14 ] ].each do |date, utc_hour|
        post calendar_events_path, params: { calendar_event: event_params.merge(starts_at_date: date, starts_at_time: "8:00") }
        assert_response :redirect
        assert_equal utc_hour, CalendarEvent.order(:id).last.starts_at.utc.hour
      end
      @event.update!(all_day: true)
      get calendar_path(start_date: "2026-09-01")
      assert_select ".calendar-grid-event", text: /Date only/, count: 0
      assert_select ".calendar-grid-event[title*='Date only']", count: 0
    end
  end

  private

  def event_params
    { title: "Volunteer breakfast", location: "Post hall", description: "Everyone welcome", starts_at_date: "12 SEP 2026", starts_at_time: "09:00", ends_at_date: "", ends_at_time: "", visibility: "members", all_day: "0" }
  end
end
