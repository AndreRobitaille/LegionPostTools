require "test_helper"

class MemberCalendarLinksTest < ActionDispatch::IntegrationTest
  setup do
    @post = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @zone = @post.calendar_time_zone
    travel_to @zone.local(2026, 10, 30, 12)
    Installation.singleton.update!(setup_completed_at: Time.current)
    @member = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Member"), email_address: "member@example.com")
    body = @post.meeting_bodies.create!(name: "Membership", slug: "membership", default_location_address: "1 Default Street")
    @meeting = create_meeting!(organization: @post, meeting_body: body, title: "Post meeting", starts_at: @zone.local(2026, 11, 1, 19),
      location_name: "Community Hall", location_address: "50 Lake Road\nTwo Rivers, WI")
    @event = @post.calendar_events.create!(title: "Veterans’ breakfast, coffee & conversation", location: "Park & Ride; east entrance",
      starts_at: @zone.local(2026, 10, 31, 23, 30), ends_at: @zone.local(2026, 11, 1, 2, 30),
      created_by: @member, updated_by: @member, website_description: "Editorial copy")
  end

  test "timed export preserves the overnight DST change, text, and member return link" do
    sign_in_as(@member)
    get calendar_event_path(@event)
    assert_response :success
    assert_equal({ "api" => "1", "query" => @event.location }, link_params("View on map", "www.google.com"))
    google = link_params("Google Calendar", "calendar.google.com")
    assert_equal "20261101T043000Z/20261101T083000Z", google["dates"]
    assert_equal "America/Chicago", google["stz"]
    assert_equal "America/Chicago", google["etz"]
    assert_equal @event.title, google["text"]
    assert_equal @event.location, google["location"]
    assert_equal calendar_event_url(@event), google["details"]

    get link_href("Apple Calendar")
    event = downloaded_event
    assert_equal google["dates"].split("/"), [ event.dtstart.value_ical, event.dtend.value_ical ]
    assert_equal google["text"], event.summary.to_s
    assert_equal google["location"], event.location.to_s
    assert_equal google["details"], event.url.to_s
    assert_empty event.rrule
    assert_no_match(/Editorial copy|#{Regexp.escape(@member.email_address)}/, response.body)
  end

  test "preview keeps its return link and rechecks visibility on a later download" do
    sign_in_as(@member)
    @event.update!(visibility: "public")
    get calendar_event_path(@event, preview: "public")
    assert_equal calendar_event_url(@event, preview: "public"), link_params("Google Calendar", "calendar.google.com")["details"]
    path = link_href("Apple Calendar")
    get path
    assert_equal calendar_event_url(@event, preview: "public"), downloaded_event.url.to_s
    @event.update!(visibility: "members")
    get path
    assert_response :not_found
    get meeting_path(@meeting, format: :ics, preview: "public")
    assert_response :not_found
  end

  test "start-only events keep literal punctuation, multiline text and identity across a reschedule" do
    sign_in_as(@member)
    @event.update!(ends_at: nil, title: 'Supper, setup; café \north', location: "Veterans Hall\rWest entrance")
    get calendar_event_path(@event, format: :ics)
    event = downloaded_event
    assert_equal @event.title, event.summary.to_s
    assert_equal "Veterans Hall\nWest entrance", event.location.to_s
    assert_nil event.dtend
    assert_nil event.duration
    @event.update!(starts_at: @event.starts_at + 1.day)
    get calendar_event_path(@event, format: :ics)
    updated = downloaded_event
    assert_equal event.uid.to_s, updated.uid.to_s
    assert_not_equal event.dtstart.value_ical, updated.dtstart.value_ical
  end

  test "opening a saved preview after sign-out keeps its visibility check through sign-in" do
    @event.update!(visibility: "public")
    sign_in_as(@member)
    get calendar_event_path(@event, format: :ics, preview: "public")
    saved_url = downloaded_event.url.to_s
    delete session_path
    get "#{saved_url}&token=discard-me"
    assert_redirected_to new_session_path
    @event.update!(visibility: "members")
    post magic_link_session_path, params: { token: MagicLink.create_for!(@member).token }
    assert_redirected_to saved_url
    follow_redirect!
    assert_response :not_found
  end

  test "all-day exports include the last local day and expire at the following midnight" do
    sign_in_as(@member)
    @event.update!(all_day: true, starts_at: @zone.local(2026, 10, 31), ends_at: @zone.local(2026, 11, 2).end_of_day)
    [ [ nil, "20261101" ], [ @event.ends_at, "20261103" ] ].each do |finish, expected_end|
      @event.update!(ends_at: finish)
      get calendar_event_path(@event)
      assert_equal "20261031/#{expected_end}", link_params("Google Calendar", "calendar.google.com")["dates"]
      get link_href("Apple Calendar")
      event = downloaded_event
      assert_instance_of Icalendar::Values::Date, event.dtstart
      assert_equal "20261031", event.dtstart.value_ical
      assert_equal expected_end, event.dtend.value_ical
    end

    travel_to @zone.local(2026, 11, 2, 23, 59)
    get calendar_event_path(@event, format: :ics)
    assert_response :success
    travel_to @zone.local(2026, 11, 3)
    assert_unavailable(@event)
  end

  test "meeting uses its own address and expresses an unspecified end time" do
    sign_in_as(@member)
    get meeting_path(@meeting)
    assert_select ".meeting-record-head", text: /19:00/
    assert_equal "50 Lake Road Two Rivers, WI", link_params("View on map", "www.google.com")["query"]
    google = link_params("Google Calendar", "calendar.google.com")
    assert_equal "20261102T010000Z/20261102T010000Z", google["dates"]
    assert_includes google["details"], "End time not specified."
    assert_includes google["details"], meeting_url(@meeting)
    get link_href("Apple Calendar")
    meeting = downloaded_event
    assert_equal @meeting.title, meeting.summary.to_s
    assert_equal "20261102T010000Z", meeting.dtstart.value_ical
    assert_nil meeting.dtend
    assert_nil meeting.duration
    assert_includes meeting.location.to_s, @meeting.location_address
    assert_equal meeting_url(@meeting), meeting.url.to_s
    assert_no_match(/Default Street/, response.body)
  end

  test "blank, unknown and online places do not offer a map" do
    sign_in_as(@member)
    [ "", "TBD", "Location not recorded", "To be announced", "Online only", "Zoom", "Teams meeting", "https://meet.example.org/123" ].each do |place|
      @event.update!(location: place)
      get calendar_event_path(@event)
      assert_select "a[href*='google.com/maps']", count: 0
      assert_select "dd", text: place if place.present?
    end
    @meeting.update!(location_name: "Virtual meeting")
    get meeting_path(@meeting)
    assert_select "a[href*='google.com/maps']", count: 0
  end

  test "cancelled and elapsed records cannot be saved from an old page or file link" do
    sign_in_as(@member)
    [ @event, @meeting ].each do |entry|
      entry.update!(cancelled: true)
      assert_unavailable(entry)
      entry.update!(cancelled: false)
    end
    travel_to @event.starts_at + 30.minutes
    get calendar_event_path(@event, format: :ics)
    assert_response :success
    travel_to @meeting.starts_at + 1.minute
    [ @event, @meeting ].each { |entry| assert_unavailable(entry) }
    @event.update!(ends_at: nil)
    assert_unavailable(@event)
  end

  test "downloads require a current member session and a record in this Post" do
    [ @event, @meeting ].each do |entry|
      get polymorphic_path(entry, format: :ics)
      assert_redirected_to new_session_path
    end
    sign_in_as(@member)
    other = Organization.create!(name: "Another Post", unit_type: "american_legion_post")
    event = other.calendar_events.create!(title: "Other event", starts_at: 1.week.from_now, created_by: @member, updated_by: @member)
    body = other.meeting_bodies.create!(name: "Another body", slug: "another")
    meeting = create_meeting!(organization: other, meeting_body: body, starts_at: 1.week.from_now)
    [ event, meeting ].each do |entry|
      get polymorphic_path(entry, format: :ics)
      assert_response :not_found
    end
    @member.update!(disabled_at: Time.current)
    get calendar_event_path(@event, format: :ics)
    assert_redirected_to new_session_path
  end

  private

  def link_href(label)
    link = css_select("a").find { |node| node.text.include?(label) }
    assert link, "Expected link #{label}"
    link["href"]
  end

  def link_params(label, host)
    uri = URI(link_href(label))
    assert_equal host, uri.host
    URI.decode_www_form(uri.query).to_h
  end

  def downloaded_event
    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Cache-Control"], "no-store"
    events = Icalendar::Calendar.parse(response.body).sole.events
    events.sole
  end

  def assert_unavailable(entry)
    get polymorphic_path(entry)
    assert_response :success
    assert_select "summary", text: "Add to calendar", count: 0
    get polymorphic_path(entry, format: :ics)
    assert_response :not_found
  end
end
