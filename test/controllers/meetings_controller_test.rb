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
    assert_select ".meeting-document-unavailable", text: /agenda has not been published yet/i
    assert_select ".meeting-document-card", count: 0
  end

  test "past meeting retains the agenda link and identifies missing minutes" do
    agenda = create_dated_agenda!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.ago, title: "Recorded Meeting")
    manager = User.create!(person: Person.create!(first_name: "Test", last_name: "Manager"), email_address: "manager@example.com", email_verified_at: Time.current)
    agenda.approve!(manager)
    agenda.publish!(manager)
    sign_in_as(@user)
    get meeting_path(agenda.meeting)

    assert_response :success
    assert_select "a[href='#{dated_agenda_path(agenda)}']", text: /Agenda.*Published.*Open/m
    assert_select ".meeting-document-unavailable", text: /Minutes have not been published yet/
  end

  test "attested revision is member visible while still awaiting membership approval" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.ago, title: "July Membership")
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    minutes.sections.first.items.create!(
      title: "Adjutant report", behavior_type: "report_slot", position: 1,
      agenda_body: "<ul><li>Read the minutes.</li></ul>",
      body: '<p>The minutes were read.</p><ol><li><span class="lexxy-content__bold" onmouseover="alert(1)">Follow-up</span></li></ol><script>alert(1)</script><a href="javascript:alert(1)">Unsafe link</a>'
    )
    approver = lifecycle_user("Commander", "approve_minutes")
    attester = lifecycle_user("Adjutant", "attest_minutes")
    approval_token, = AgentAccessToken.issue!(user: approver, name: "Approval", expires_in: 1.day)
    minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: approval_token, action: "approve"))
    attestation = OfficialActionConfirmation.record_external!(minutes:, user: attester, action: "attest", evidence_note: "Written approval.")
    minutes.attest_with_confirmation!(confirmation: attestation, recorded_by: approver)
    sign_in_as(@user)

    get meeting_path(meeting)
    assert_response :success
    assert_select "a[href='#{meeting_minutes_path(meeting)}']", text: /Minutes.*Awaiting meeting approval.*Open/m

    get meeting_minutes_path(meeting)
    assert_response :success
    assert_select ".member-minutes-status", text: /Awaiting meeting approval/
    assert_select ".member-meeting-document article.agenda-doc", count: 1
    assert_select ".member-minutes-provenance", text: /Commander draft handoff.*Adjutant attestation/m
    assert_select ".member-minutes-attestation > p", text: /Attested by Test Adjutant/
    assert_select ".minutes-item-title", text: "Adjutant report"
    assert_select ".minutes-agenda-wording.lexxy-content ul li", text: "Read the minutes."
    assert_select ".minutes-recorded-wording .lexxy-content ol li .lexxy-content__bold", text: "Follow-up"
    assert_select ".lexxy-content script, .lexxy-content [onmouseover], .lexxy-content a[href^='javascript:']", count: 0
    assert_no_match(/official minutes/i, response.body)

    get meetings_path
    assert_select "a[href='#{meeting_minutes_path(meeting)}']", text: "View minutes"
    assert_select ".member-meeting-note", text: "Awaiting meeting approval"
    assert_select ".meeting-year .agenda-docket-meta", count: 0
  end

  test "membership-approved revision is presented as the official minutes" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.month.ago, title: "July Membership")
    approving_meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.day.ago, title: "September Membership")
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    approver = lifecycle_user("Commander", "approve_minutes")
    approver.permission_grants.create!(capability: "record_minutes_approval")
    attester = lifecycle_user("Adjutant", "attest_minutes")
    approval_token, = AgentAccessToken.issue!(user: approver, name: "Approval", expires_in: 1.day)
    attestation_token, = AgentAccessToken.issue!(user: attester, name: "Attestation", expires_in: 1.day)
    minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: approval_token, action: "approve"))
    minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: attestation_token, action: "attest"))
    minutes.record_membership_approval_with_confirmation!(
      confirmation: OfficialActionConfirmation.for_delegated_agent!(
        minutes:,
        agent_access_token: approval_token,
        action: "record_membership_approval",
        action_payload: { approving_meeting_id: approving_meeting.id, disposition: "approved_as_corrected" }
      )
    )
    sign_in_as(@user)

    get meeting_path(meeting)
    assert_select ".meeting-document-card", text: /Minutes.*Official record.*Approved as corrected.*September Membership/m

    get meeting_minutes_path(meeting)

    assert_response :success
    assert_select ".minutes-eyebrow", text: "Official minutes"
    assert_select ".member-minutes-status", text: /Approved as corrected.*September Membership/m
    assert_select ".member-minutes-provenance", text: /Meeting approval.*Approved as corrected/m
  end

  test "member paper always uses the attested snapshot while working corrections change" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.month.ago, title: "Attested meeting title", location_name: "Recorded Hall")
    later_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago, title: "Later Membership")
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    item = minutes.sections.first.items.create!(title: "Community breakfast", behavior_type: "business_item", position: 1, body: "Twelve volunteers attended.")
    motion = item.outcomes.create!(kind: "motion", text: "Hold a community breakfast.", disposition: "adopted", mover_name: "Alex Member", seconder_name: "Pat Member", vote_summary: "Passed unanimously.", position: 1)
    item.outcomes.create!(kind: "decision", text: "Check the available supplies.", disposition: "no_vote", mover_name: "Morgan Member", seconder_name: "Taylor Member", position: 2)
    attendance = minutes.attendance_entries.create!(office_name: "Adjutant", person_name: "Recorded Officer", status: "present", position: 1)
    commander = lifecycle_user("Commander", "approve_minutes")
    commander.permission_grants.create!(capability: "manage_minutes")
    commander.permission_grants.create!(capability: "record_minutes_approval")
    adjutant = lifecycle_user("Adjutant", "attest_minutes")
    commander_token, = AgentAccessToken.issue!(user: commander, name: "Test Commander", expires_in: 1.day)
    adjutant_token, = AgentAccessToken.issue!(user: adjutant, name: "Test Adjutant", expires_in: 1.day)
    attest = -> { minutes.reload.attest_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: adjutant_token, action: "attest")) }
    attest.call
    first_revision = minutes.current_revision
    sign_in_as(@user)

    minutes.reopen_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: commander_token, action: "reopen", action_payload: { reason: "Correct the volunteer count." }))
    minutes.update!(title: "Working meeting title", location_name: "Working Hall")
    item.update!(body: "Thirteen volunteers attended.")
    motion.update!(text: "Working motion text.")
    attendance.update!(person_name: "Working Officer")
    minutes.reload
    minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: commander_token, action: "approve"))

    get meeting_minutes_path(meeting)

    assert_response :success
    assert_select "h1", text: "Attested meeting title"
    assert_select ".agenda-meeting-location-name", text: "Recorded Hall"
    assert_select ".member-minutes-status", text: /Correction in progress.*last attested copy/m
    assert_select ".minutes-recorded-wording", text: /Twelve volunteers attended/
    assert_select ".minutes-doc-outcome-text", text: "Hold a community breakfast."
    assert_select ".minutes-doc-outcome-facts", text: /Alex Member.*Pat Member.*Passed.*Passed unanimously/m
    assert_select ".minutes-doc-outcome-facts", text: /Morgan Member.*Taylor Member.*No vote/m
    assert_select ".minutes-doc-attendance tbody", text: /Recorded Officer.*Present/m
    assert_select ".member-minutes-provenance code", text: first_revision.sha256.first(12)
    assert_no_match(/Working meeting title|Working Hall|Working motion text|Working Officer|Thirteen volunteers/, response.body)
    assert_equal first_revision.sha256, first_revision.reload.sha256

    attest.call
    second_revision = minutes.current_revision
    minutes.record_membership_approval_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: commander_token, action: "record_membership_approval", action_payload: { approving_meeting_id: later_meeting.id, disposition: "approved_as_corrected", corrections_pending: true, factual_note: "Correct the final volunteer count." }))
    item.update!(body: "Fourteen volunteers attended.")

    get meeting_minutes_path(meeting)

    assert_select ".member-minutes-status", text: /Approved with corrections.*final copy being prepared.*last attested copy/m
    assert_select ".minutes-recorded-wording", text: /Thirteen volunteers attended/
    assert_select ".member-minutes-provenance code", text: second_revision.sha256.first(12)
    assert_no_match(/Fourteen volunteers/, response.body)
    assert_select ".member-minutes-provenance", text: /Meeting approval/, count: 0

    attest.call
    get meeting_minutes_path(meeting)

    assert_select ".member-minutes-status--final", text: /Approved as corrected.*final, locked record/m
    assert_select ".minutes-recorded-wording", text: /Fourteen volunteers attended/
    assert_select ".member-minutes-provenance", text: /Later Membership.*Approval recorded by.*Test Commander/m
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
