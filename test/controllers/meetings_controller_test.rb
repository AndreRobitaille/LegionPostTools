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
    assert_select ".meeting-next .member-meeting-card", text: /Next Membership Meeting/
    assert_select ".meeting-list-section .member-meeting-row", text: /Later Membership Meeting/
    assert_select ".meeting-year#meetings-2025 .member-meeting-row", text: /August 2025 Meeting/
    assert_select ".meeting-year-rail a[href='#meetings-2025']", text: "2025"
    assert_select "a[href='#{meeting_path(next_meeting)}']", count: 0
    assert_select "a[href='#{meeting_path(later)}']", count: 0
    assert_select "a[href='#{meeting_path(past)}']", count: 0
  end

  test "index links directly to a published upcoming agenda and removes generated title repetition" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now)
    agenda = DatedAgenda.create_from_template!(meeting:)
    publisher = lifecycle_user("Publisher", "manage_agendas")
    agenda.approve!(publisher)
    agenda.publish!(publisher)
    sign_in_as(@user)

    get meetings_path

    assert_select ".meeting-next h2", text: "Membership Meeting"
    assert_select "a[href=?]", dated_agenda_path(agenda), text: "View agenda"
    assert_select ".member-meeting-schedule", text: /#{Regexp.escape(meeting.location_name)}/
    assert_select ".meeting-next", text: /Membership Meeting —/, count: 0
  end

  test "index presents unavailable upcoming agendas as noninteractive" do
    create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now)
    sign_in_as(@user)

    get meetings_path

    assert_select ".member-document-action--unavailable[aria-disabled=true]", text: "Agenda not published yet"
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

  test "attested revision is member visible while still awaiting acceptance" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.ago, title: "July Membership")
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    minutes.sections.first.items.create!(title: "Adjutant report", behavior_type: "report_slot", position: 1, body: "The minutes were read.")
    approver = lifecycle_user("Commander", "approve_minutes")
    attester = lifecycle_user("Adjutant", "attest_minutes")
    approval_token, = AgentAccessToken.issue!(user: approver, name: "Approval", expires_in: 1.day)
    minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: approval_token, action: "approve"))
    attestation = OfficialActionConfirmation.record_external!(minutes:, user: attester, action: "attest", evidence_note: "Written approval.")
    minutes.attest_with_confirmation!(confirmation: attestation, recorded_by: approver)
    sign_in_as(@user)

    get meeting_path(meeting)
    assert_response :success
    assert_select "a[href='#{meeting_minutes_path(meeting)}']", text: /minutes awaiting acceptance/i

    get meeting_minutes_path(meeting)
    assert_response :success
    assert_select ".member-minutes-status", text: /Awaiting acceptance/
    assert_select ".minutes-endorsements", text: /Commander approval.*Adjutant attestation/m
    assert_select ".minutes-item-title", text: "Adjutant report"
    assert_no_match(/official minutes/i, response.body)

    get meetings_path
    assert_select "a[href='#{meeting_minutes_path(meeting)}']", text: "View minutes"
    assert_select ".member-meeting-note", text: "Awaiting member acceptance"
    assert_select ".meeting-year .agenda-docket-meta", count: 0
  end

  private

  def lifecycle_user(office, capability)
    person = Person.create!(first_name: "Test", last_name: office)
    user = User.create!(person:, email_address: "#{office.downcase}-#{SecureRandom.hex(3)}@example.com", email_verified_at: Time.current)
    user.permission_grants.create!(capability:)
    title = @organization.position_titles.find_or_create_by!(name: office) { |record| record.display_order = @organization.position_titles.count + 1 }
    title.position_assignments.create!(person:, starts_on: 1.year.ago.to_date)
    user
  end
end
