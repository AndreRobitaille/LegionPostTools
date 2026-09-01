require "test_helper"

class MeetingMinutesPdfSourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      locality: "Two Rivers, Wisconsin",
      mailing_address: "P.O. Box 11\nTwo Rivers, WI 54241",
      public_email: "post@example.com",
      timezone: "America/Chicago"
    )
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    meeting = create_meeting!(organization: @organization, meeting_body: body, meeting_type: type, starts_at: 1.day.ago)
    @minutes = MeetingMinutes.create_from_meeting!(meeting:)
    creator = User.create!(
      person: Person.create!(first_name: "Casey", last_name: "Adjutant"),
      email_address: "pdf-adjutant@example.com",
      email_verified_at: Time.current
    )
    endeavor = @organization.endeavors.create!(
      created_by: creator,
      title: "Car & Bike Show 2026",
      importance: "standard",
      status: "active"
    )
    @item = @minutes.sections.first.items.create!(
      title: "Finance report",
      behavior_type: "report_slot",
      position: 1,
      agenda_body: "Bring the proposed flag purchase to the membership.",
      body: "The balance was $1,234.",
      endeavor:
    )
    @item.outcomes.create!(kind: "motion", text: "Purchase four new flags.", disposition: "adopted", mover_name: "Pat Member", seconder_name: "Alex Member", vote_summary: "Unanimous", position: 1)
    @item.outcomes.create!(kind: "motion", text: "Raise annual dues.", disposition: "lost", mover_name: "Morgan Member", seconder_name: "Taylor Member", position: 2)
    @item.outcomes.create!(kind: "motion", text: "Table the building proposal.", disposition: "postponed", position: 3)
    @minutes.attendance_entries.create!(office_name: "Commander", person_name: "Pat Commander", status: "present", position: 1)
    @minutes.attendance_entries.create!(office_name: "First Vice Commander", status: "vacant", position: 2)
  end

  test "source is a chrome-free draft document with minutes content" do
    get meeting_minutes_pdf_source_path(token: MeetingMinutesPdf.source_token(minutes: @minutes))

    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "body.print-body"
    assert_select ".minutes-doc-status-label--draft", text: /Draft - not approved/i
    assert_select ".agenda-meeting-heading h1", text: "Membership Meeting - Draft minutes"
    assert_select ".minutes-doc-attendance", text: /Commander.*Pat Commander.*Present/m
    assert_select ".minutes-doc-attendance", text: /First Vice Commander.*Vacant.*Vacant/m
    assert_select ".minutes-doc-agenda-wording", text: /proposed flag purchase/
    assert_select ".minutes-doc-recorded" do
      assert_select ".minutes-doc-narrative-label", text: "Recorded minutes"
      assert_select ".minutes-doc-narrative .agenda-item-body", text: /balance was \$1,234/
      assert_select ".minutes-doc-agenda-wording", count: 0
      assert_select ".minutes-doc-outcome", count: 3
    end
    assert_select ".minutes-doc-outcome--passed", text: /Purchase four new flags/
    assert_select ".minutes-doc-outcome--failed", text: /Raise annual dues/
    assert_select ".minutes-doc-outcome--other", text: /Table the building proposal/
    assert_select ".minutes-doc-outcome-facts dt", text: "Moved by", count: 3
    assert_select ".minutes-doc-outcome-facts dt", text: "Seconded by", count: 3
    assert_select ".minutes-doc-outcome-facts dt", text: "Result", count: 3
    assert_select ".minutes-doc-outcome-note", text: /Vote \/ notes.*Unanimous/m
    assert_select ".minutes-doc-result", text: "Passed"
    assert_select ".minutes-doc-result", text: "Did not pass"
    assert_select "body", text: /Related continuing work/, count: 0
    assert_select "body", text: /Car & Bike Show 2026/, count: 0
    assert_select ".minutes-authority-folio", text: /not approved, attested, or accepted/i
    assert_select "nav", count: 0
  end

  test "attested source renders the immutable revision with truthful authority on every page" do
    attest_minutes!
    @item.update_column(:title, "Changed working row after attestation")

    get meeting_minutes_pdf_source_path(token: MeetingMinutesPdf.source_token(minutes: @minutes))

    assert_response :success
    assert_select ".minutes-doc-status-label--attested", text: "Attested - awaiting acceptance"
    assert_select ".agenda-meeting-heading h1", text: "Membership Meeting - Attested minutes"
    assert_select ".minutes-doc-item", text: /Finance report/
    assert_select ".minutes-doc-item", text: /Changed working row after attestation/, count: 0
    assert_select ".minutes-authority-folio", text: /Attested minutes - awaiting acceptance/
    assert_select ".minutes-authority-folio", text: /Approved for attestation.*Test Commander/m
    assert_select ".minutes-authority-folio", text: /Attested.*Test Adjutant/m
    assert_select ".minutes-authority-folio", text: /Acceptance.*Awaiting action at a later Membership/m
    assert_select ".agenda-doc-footer", text: /Attested - awaiting acceptance/
    assert_includes response.body, "ATTESTED - AWAITING ACCEPTANCE"
  end

  test "source rejects invalid tokens" do
    get meeting_minutes_pdf_source_path(token: "invalid")
    assert_response :not_found
  end

  test "source rejects non-loopback requests" do
    get meeting_minutes_pdf_source_path(token: MeetingMinutesPdf.source_token(minutes: @minutes)),
      headers: { "REMOTE_ADDR" => "203.0.113.9" }
    assert_response :not_found
  end

  private

  def attest_minutes!
    approver = lifecycle_user("Commander", "approve_minutes")
    attester = lifecycle_user("Adjutant", "attest_minutes")
    approval_token, = AgentAccessToken.issue!(user: approver, name: "Approval", expires_in: 1.day)
    @minutes.approve_with_confirmation!(
      confirmation: OfficialActionConfirmation.for_delegated_agent!(
        minutes: @minutes,
        agent_access_token: approval_token,
        action: "approve"
      )
    )
    attestation = OfficialActionConfirmation.record_external!(
      minutes: @minutes,
      user: attester,
      action: "attest",
      evidence_note: "Written confirmation."
    )
    @minutes.attest_with_confirmation!(confirmation: attestation, recorded_by: approver)
  end

  def lifecycle_user(office, capability)
    person = Person.create!(first_name: "Test", last_name: office)
    user = User.create!(person:, email_address: "#{office.downcase}-#{SecureRandom.hex(3)}@example.com", email_verified_at: Time.current)
    user.permission_grants.create!(capability:)
    title = @organization.position_titles.create!(name: office, display_order: @organization.position_titles.count + 1)
    title.position_assignments.create!(person:, starts_on: 1.year.ago.to_date)
    user
  end
end
