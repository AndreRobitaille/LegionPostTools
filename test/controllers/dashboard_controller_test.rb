require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication after setup" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Installation.singleton.update!(setup_completed_at: Time.current)

    get root_path

    assert_redirected_to new_session_path
  end

  test "partial setup state still redirects to setup" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    get root_path

    assert_redirected_to new_setup_path
  end

  test "true first run root redirects to setup" do
    get root_path

    assert_redirected_to new_setup_path
  end

  test "user only partial setup root redirects to setup" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)

    get root_path

    assert_redirected_to new_setup_path
  end

  test "recovery installed state unauthenticated root redirects to sign in" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)

    get root_path

    assert_redirected_to new_session_path
  end

  test "authenticated user sees dashboard" do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Andre", last_name: "Robitaille")
    user = User.create!(person: person, email_address: "andre@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Installation.singleton.update!(setup_completed_at: Time.current)
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select ".app-brand-name", organization.name
    assert_select "h1", "Post meetings"
    assert_no_match "Signed in as #{person.full_name}", response.body
    assert_select "a[href=?]", meetings_path, text: /Browse all meetings/
  end

  test "signed in user in recovery installed state can reach dashboard" do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Andre", last_name: "Robitaille")
    user = User.create!(person: person, email_address: "andre@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select ".app-brand-name", organization.name
    assert_select "h1", "Post meetings"
    assert_no_match "Signed in as #{person.full_name}", response.body
    assert_select "a[href=?]", meetings_path, text: /Browse all meetings/
  end

  test "stale sessions older than 180 days are expired" do
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    stale_session = Session.create!(
      user: user,
      ip_address: "127.0.0.1",
      user_agent: "test",
      last_seen_at: 181.days.ago
    )

    set_session_cookie(stale_session)

    get root_path

    assert_redirected_to new_session_path
    assert_nil Session.find_by(id: stale_session.id)
  end

  test "active resumed sessions update last seen periodically" do
    Installation.singleton.update!(setup_completed_at: Time.current)
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Andre", last_name: "Robitaille")
    user = User.create!(person: person, email_address: "andre@example.com", email_verified_at: Time.current)
    active_session = Session.create!(
      user: user,
      ip_address: "127.0.0.1",
      user_agent: "test",
      last_seen_at: 2.hours.ago
    )

    set_session_cookie(active_session)

    get root_path

    active_session.reload

    assert_response :success
    assert_equal "Post meetings", response.parsed_body.at("h1").text
    assert active_session.last_seen_at > 10.minutes.ago
  end

  test "shows the passkey invite when the user has no passkeys" do
    signed_in_member
    get root_path
    assert_response :success
    assert_match "Optional sign-in", response.body
    assert_select "h2", "Sign in faster with a passkey"
    assert_select "button", text: "Set up a passkey"
    assert_select "button", text: "Not now"
    assert_select "body", text: /Email sign-in will still work/
  end

  test "shows the next and most recent meetings with direct document actions" do
    signed_in_member
    organization = Organization.first
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    past = create_meeting!(organization:, meeting_body: body, meeting_type: type, starts_at: 1.week.ago)
    upcoming = create_meeting!(organization:, meeting_body: body, meeting_type: type, starts_at: 1.week.from_now)
    publisher = User.create!(person: Person.create!(first_name: "Agenda", last_name: "Publisher"), email_address: "publisher@example.com")
    agenda = DatedAgenda.create_from_template!(meeting: upcoming)
    agenda.approve!(publisher)
    agenda.publish!(publisher)

    get root_path

    assert_response :success
    assert_select ".member-dashboard-section", text: /Next meeting.*Membership Meeting.*View agenda/m
    assert_select "a[href=?]", dated_agenda_path(agenda), text: "View agenda"
    assert_select ".member-dashboard-section", text: /Most recent meeting.*No documents available/m
    assert_select ".member-meeting-card", text: /#{past.starts_at.in_time_zone.strftime('%d').to_i}/
    assert_select "a[href=?]", meeting_path(past), count: 0
  end

  test "keeps member meetings separate and shows only the next three eligible activities" do
    user = signed_in_member
    organization = Organization.first
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    past = create_meeting!(organization:, meeting_body: body, starts_at: 1.week.ago, title: "Last member meeting", calendar_category: "member_meeting")
    upcoming = create_meeting!(organization:, meeting_body: body, starts_at: 1.week.from_now, title: "Next member meeting", calendar_category: "member_meeting")
    %w[officer_meeting honor_guard].each do |category|
      [ 1.day.ago, 1.day.from_now ].each do |date|
        create_meeting!(organization:, meeting_body: body, starts_at: date, title: "Excluded #{category}", calendar_category: category)
      end
    end
    planning = create_meeting!(organization:, meeting_body: body, starts_at: 3.days.from_now, title: "Parade planning", calendar_category: "planning_meeting")
    event = ->(title, days, **attributes) {
      organization.calendar_events.create!(title:, starts_at: days.days.from_now, created_by: user, updated_by: user, **attributes)
    }
    public_event = event.call("Community breakfast", 2, visibility: "public")
    other = event.call("Post social", 4, calendar_category: "other")
    event.call("Fourth activity", 5)
    event.call("Past event", -1)
    event.call("Cancelled event", 1, cancelled: true)
    event.call("Honor Guard public ceremony", 1, visibility: "public")
    event.call("PEC meeting", 1)
    event.call("Member Meeting", 1)
    elsewhere = Organization.create!(name: "Another Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    elsewhere.calendar_events.create!(title: "Another Post event", starts_at: 1.day.from_now, created_by: user, updated_by: user)

    get root_path

    assert_response :success
    assert_select ".member-meeting-card h2", text: past.title
    assert_select ".member-meeting-card h2", text: upcoming.title
    assert_select ".dashboard-activity h2" do |titles|
      assert_equal [ public_event.title, planning.title, other.title ], titles.map(&:text)
    end
    assert_select ".dashboard-activities a[href=?]", calendar_event_path(public_event)
    assert_select ".dashboard-activities a[href=?]", meeting_path(planning)
    assert_select ".dashboard-activities a[href=?]", calendar_path, text: "View full calendar"
  end

  test "activities use the Post date and retain ongoing events without a month cutoff" do
    user = signed_in_member
    organization = Organization.first
    organization.update!(timezone: "America/Los_Angeles")
    travel_to Time.utc(2026, 9, 7, 5) do
      organization.calendar_events.create!(title: "Today at the Post", starts_at: Time.utc(2026, 9, 6, 17), created_by: user, updated_by: user)
      organization.calendar_events.create!(title: "Weekend festival", starts_at: 2.days.ago, ends_at: 1.day.from_now, created_by: user, updated_by: user)
      organization.calendar_events.create!(title: "Later this year", starts_at: 2.months.from_now, created_by: user, updated_by: user)
      organization.calendar_events.create!(title: "Yesterday at the Post", starts_at: Time.utc(2026, 9, 6, 6), created_by: user, updated_by: user)

      get root_path

      assert_select ".dashboard-activity h2" do |titles|
        assert_equal [ "Weekend festival", "Today at the Post", "Later this year" ], titles.map(&:text)
      end
      assert_select ".dashboard-activity time[datetime='2026-09-06']"
    end
  end

  test "hides the activities section when there are no eligible events" do
    user = signed_in_member
    Organization.first.calendar_events.create!(title: "PEC meeting", starts_at: 1.day.from_now, created_by: user, updated_by: user)

    get root_path

    assert_response :success
    assert_select ".dashboard-activities", count: 0
    assert_select ".member-dashboard-section", count: 2
  end

  test "hides the passkey invite when the user already has a passkey" do
    user = signed_in_member
    PasskeyCredential.create!(user: user, external_id: "cid", public_key: "pk", sign_count: 0)
    get root_path
    assert_response :success
    assert_select ".pk-card--sidebar", count: 0
  end

  test "shows roster email review prompt when needed" do
    user = signed_in_member
    user.person.update!(roster_email_address: "roster@example.com")
    user.update!(email_address: "login@example.com")

    get root_path

    assert_response :success
    assert_select "h2", "Review your login email"
  end

  test "remind later does not show the roster email review prompt again in the same session" do
    user = signed_in_member
    user.person.update!(roster_email_address: "roster@example.com")
    user.update!(email_address: "login@example.com")

    patch roster_email_review_path, params: { decision: "remind_later" }

    assert_redirected_to root_path

    get root_path

    assert_response :success
    assert_no_match "Review your login email", response.body
  end

  test "remind later shows the roster email review prompt again in a new signed-in session" do
    user = signed_in_member
    user.person.update!(roster_email_address: "roster@example.com")
    user.update!(email_address: "login@example.com")

    patch roster_email_review_path, params: { decision: "remind_later" }

    assert_redirected_to root_path

    open_session do |new_session|
      new_session.sign_in_as(user)
      new_session.get root_path

      new_session.assert_response :success
      new_session.assert_select "h2", "Review your login email"
    end
  end

  test "does not show roster email review prompt when roster and login emails match" do
    user = signed_in_member
    user.person.update!(roster_email_address: "jane@example.com")

    get root_path

    assert_response :success
    assert_no_match "Review your login email", response.body
  end

  test "invite stays hidden after dismissal within the session" do
    signed_in_member
    delete passkey_invitation_path
    assert_redirected_to root_path

    get root_path
    assert_response :success
    assert_select ".pk-card--sidebar", count: 0
  end

  private

  # A fully set-up, signed-in member with no passkeys yet.
  def signed_in_member
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Installation.singleton.update!(setup_completed_at: Time.current)
    sign_in_as(user)
    user
  end

  def set_session_cookie(session_record)
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session_record.id
    cookies[:session_id] = jar["session_id"]
  end
end
