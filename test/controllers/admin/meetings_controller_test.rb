require "test_helper"

class Admin::MeetingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Legion Hall",
      default_location_address: "123 Main Street",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    entry = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true)
    @type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: entry, position: 1, title: "Opening", active: true)
    @manager = create_user("manage_agendas")
  end

  test "signed out and unauthorized users cannot manage meetings" do
    get admin_meetings_path
    assert_redirected_to new_session_path

    sign_in_as(create_user)
    get admin_meetings_path
    assert_redirected_to root_path
  end

  test "index separates upcoming and past meetings" do
    upcoming = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now, title: "Upcoming Meeting")
    past = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.ago, title: "Past Meeting")
    sign_in_as(@manager)

    get admin_meetings_path

    assert_response :success
    assert_select ".admin-meeting-section", count: 2
    assert_select "a[href='#{admin_meeting_path(upcoming)}']", text: /Upcoming Meeting/
    assert_select "a[href='#{admin_meeting_path(past)}']", text: /Past Meeting/
    assert_select "a[href='#{new_admin_meeting_path}']", text: "Schedule a meeting"
  end

  test "minutes managers can open records without agenda mutation controls" do
    past = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.ago, title: "Past Meeting")
    minutes_manager = create_user("manage_minutes")
    sign_in_as(minutes_manager)

    get admin_meetings_path
    assert_response :success
    assert_select "a[href='#{admin_meeting_path(past)}']", text: /Past Meeting/
    assert_select "a[href='#{new_admin_meeting_path}']", count: 0

    get admin_meeting_path(past)
    assert_response :success
    assert_select "a[href='#{edit_admin_meeting_path(past)}']", count: 0
    assert_select "form[action='#{admin_meeting_minutes_path(past)}'] button", text: "Begin minutes"

    get edit_admin_meeting_path(past)
    assert_redirected_to root_path
  end

  test "agenda-only managers do not see draft minutes or transcript status" do
    past = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.ago)
    MeetingMinutes.create_from_meeting!(meeting: past)
    MeetingTranscripts::Create.new(
      meeting: past,
      created_by: @manager,
      pasted_text: "Restricted source words",
      retention_policy: "delete_after_acceptance"
    ).call
    sign_in_as(@manager)

    get admin_meetings_path
    assert_response :success
    assert_select "a[href='#{admin_meeting_path(past)}']", text: /Agenda not started/
    assert_no_match(/Draft minutes|Transcript ready/, response.body)

    get admin_meeting_path(past)
    assert_response :success
    assert_select "a[href='#{admin_meeting_minutes_path(past)}']", count: 0
    assert_select ".meeting-minutes-workflow", text: /Restricted officer record/
    assert_no_match(/Restricted source words/, response.body)
  end

  test "new uses body place defaults and renders plain meeting fields" do
    sign_in_as(@manager)
    get new_admin_meeting_path

    assert_response :success
    assert_select "form.stacked-form[data-controller='meeting-place']"
    assert_select "select[name='meeting[meeting_body_id]']"
    assert_select "select[name='meeting[meeting_type_id]']"
    assert_select "input[name='meeting[starts_at_date]']"
    assert_select "input[name='meeting[starts_at_time]'][required]"
    assert_select "input[name='meeting[location_name]'][value='Legion Hall']"
  end

  test "create schedules a meeting without creating an agenda" do
    sign_in_as(@manager)

    assert_difference -> { Meeting.count }, 1 do
      assert_no_difference -> { DatedAgenda.count } do
        post admin_meetings_path, params: { meeting: {
          meeting_body_id: @body.id,
          meeting_type_id: @type.id,
          starts_at_date: "08 SEP 2026",
          starts_at_time: "19:00",
          title: "September Membership",
          location_name: "Community Room",
          location_address: "456 State Street"
        } }
      end
    end

    meeting = Meeting.order(:created_at).last
    assert_redirected_to admin_meeting_path(meeting)
    assert_equal Time.zone.local(2026, 9, 8, 19), meeting.starts_at
    assert_equal "Community Room", meeting.location_name
  end

  test "invalid create returns guided errors" do
    sign_in_as(@manager)
    post admin_meetings_path, params: { meeting: { meeting_body_id: @body.id, starts_at_date: "08 SEP 2026", starts_at_time: "24:00", location_name: "" } }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Starts at can't be blank/
  end

  test "prepare agenda copies template into the meeting" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now, title: "September Membership")
    sign_in_as(@manager)

    assert_difference -> { DatedAgenda.count }, 1 do
      post agenda_admin_meeting_path(meeting)
    end

    agenda = meeting.reload.dated_agenda
    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal [ "Opening" ], agenda.dated_agenda_items.pluck(:title)
    assert_equal meeting.location_name, agenda.location_name
  end

  test "meeting type is required before preparing an agenda" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.from_now, title: "Unclassified Meeting")
    sign_in_as(@manager)

    assert_no_difference -> { DatedAgenda.count } do
      post agenda_admin_meeting_path(meeting)
    end

    assert_redirected_to edit_admin_meeting_path(meeting)
    assert_match(/Meeting type must be chosen/, flash[:alert])
  end

  test "draft agenda heading follows meeting edits" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now)
    meeting = agenda.meeting
    sign_in_as(@manager)

    patch admin_meeting_path(meeting), params: { meeting: {
      starts_at_date: "15 SEP 2026",
      starts_at_time: "19:30",
      title: "Changed Assembly",
      location_name: "New Hall",
      location_address: "789 River Road",
      meeting_body_id: @body.id,
      meeting_type_id: @type.id,
      lock_version: meeting.lock_version
    } }

    assert_redirected_to admin_meeting_path(meeting)
    assert_equal "Changed Assembly", agenda.reload.title
    assert_equal "New Hall", agenda.location_name
    assert_equal Time.zone.local(2026, 9, 15, 19, 30), agenda.starts_at
  end

  test "locked agenda prevents heading changes until reopened" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now)
    agenda.approve!(@manager)
    meeting = agenda.meeting
    sign_in_as(@manager)

    patch admin_meeting_path(meeting), params: { meeting: {
      meeting_body_id: @body.id,
      meeting_type_id: @type.id,
      starts_at_date: meeting.starts_at.strftime("%d %b %Y"),
      starts_at_time: meeting.starts_at.strftime("%H:%M"),
      title: "Changed after approval",
      location_name: meeting.location_name,
      lock_version: meeting.lock_version
    } }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Reopen the agenda/
    assert_not_equal "Changed after approval", meeting.reload.title
  end

  test "only an empty meeting can be deleted" do
    empty = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.from_now, title: "Empty Meeting")
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 2.weeks.from_now)
    sign_in_as(@manager)

    assert_difference -> { Meeting.count }, -1 do
      delete admin_meeting_path(empty)
    end
    assert_response :see_other

    assert_no_difference -> { Meeting.count } do
      delete admin_meeting_path(agenda.meeting)
    end
    assert_redirected_to admin_meeting_path(agenda.meeting)
  end

  private

  def create_user(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
