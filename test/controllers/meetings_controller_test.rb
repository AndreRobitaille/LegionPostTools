require "test_helper"

class MeetingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    person = Person.create!(first_name: "Test", last_name: "Member")
    @user = User.create!(person: person, email_address: "member@example.com", email_verified_at: Time.current)
  end

  test "signed out users are redirected" do
    get meetings_path
    assert_redirected_to new_session_path
  end

  test "index features the next meeting and groups all past meetings by year" do
    past = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: Time.zone.local(2025, 8, 4, 19), title: "August 2025 Meeting")
    next_meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 2.days.from_now, title: "Next Membership Meeting")
    later = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 2.weeks.from_now, title: "Later Membership Meeting")
    sign_in_as(@user)

    get meetings_path

    assert_response :success
    assert_select ".meeting-next-card[href='#{meeting_path(next_meeting)}']", text: /Next Membership Meeting/
    assert_select ".meeting-list-section a[href='#{meeting_path(later)}']", text: /Later Membership Meeting/
    assert_select ".meeting-year#meetings-2025 a[href='#{meeting_path(past)}']", text: /August 2025 Meeting/
    assert_select ".meeting-year-rail a[href='#meetings-2025']", text: "2025"
  end

  test "meeting without an agenda is visible with honest state text" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.from_now, title: "Open Meeting")
    sign_in_as(@user)
    get meeting_path(meeting)

    assert_response :success
    assert_select "h1", text: "Open Meeting"
    assert_select ".meeting-facts", text: /agenda has not been published yet/i
  end

  test "past meeting retains the agenda link and identifies missing minutes" do
    agenda = create_dated_agenda!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.ago, title: "Recorded Meeting")
    manager = User.create!(person: Person.create!(first_name: "Test", last_name: "Manager"), email_address: "manager@example.com", email_verified_at: Time.current)
    agenda.approve!(manager)
    agenda.publish!(manager)
    sign_in_as(@user)
    get meeting_path(agenda.meeting)

    assert_response :success
    assert_select "a[href='#{dated_agenda_path(agenda)}']", text: /Read the published agenda/
    assert_select ".meeting-document-note", text: /Minutes have not been published yet/
  end
end
