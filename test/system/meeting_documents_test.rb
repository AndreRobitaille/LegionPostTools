require "application_system_test_case"

class MeetingDocumentsTest < ApplicationSystemTestCase
  test "members can distinguish and open both meeting documents on desktop and phone" do
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    meeting = create_meeting!(organization: @organization, meeting_body: body, meeting_type: type, starts_at: 1.week.ago, title: "Membership Meeting")
    commander = officer("Commander", "approve_minutes")
    adjutant = officer("Adjutant", "attest_minutes")
    agenda = DatedAgenda.create_from_template!(meeting:)
    agenda.approve!(commander)
    agenda.publish!(commander)
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    token, = AgentAccessToken.issue!(user: commander, name: "Test approval", expires_in: 1.day)
    minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: token, action: "approve"))
    minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes:, user: adjutant, action: "attest", evidence_note: "Test written attestation."), recorded_by: commander)
    member = User.create!(person: Person.create!(first_name: "General", last_name: "Member"), email_address: "documents-member@example.com")
    system_sign_in(member)
    page.current_window.resize_to(1400, 1000)
    visit meeting_path(meeting)
    assert_selector ".meeting-document-card", count: 2
    assert_selector ".meeting-document-status", text: "Awaiting membership approval", count: 1
    assert_selector ".meeting-document-open", text: "Open", count: 2
    page.save_screenshot("/tmp/meeting-documents-desktop.png")
    first(".meeting-document-card").send_keys(:tab)
    assert_selector ".meeting-document-card:focus"
    first(".meeting-document-card").click
    assert_current_path meeting_minutes_path(meeting)
    visit meeting_path(meeting)
    page.current_window.resize_to(390, 844)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot("/tmp/meeting-documents-mobile.png")
    find(".meeting-document-card", text: "Agenda").click
    assert_current_path dated_agenda_path(agenda)
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  private

  def officer(name, capability)
    person = Person.create!(first_name: "Test", last_name: name)
    user = User.create!(person:, email_address: "documents-#{name.downcase}@example.com")
    user.permission_grants.create!(capability:)
    position = @organization.position_titles.create!(name:, display_order: @organization.position_titles.count + 1)
    position.position_assignments.create!(person:, starts_on: 1.year.ago.to_date)
    user
  end
end
