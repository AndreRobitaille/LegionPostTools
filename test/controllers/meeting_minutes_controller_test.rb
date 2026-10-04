require "test_helper"

class MeetingMinutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.ago, title: "Recorded Membership Meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @item = @minutes.sections.first.items.create!(title: "Community report", behavior_type: "report_slot", position: 1, body: "Attested narrative.")
    @member = create_user("Member")
    @adjutant = create_user("Adjutant", "attest_minutes", "manage_minutes", "record_minutes_approval")
  end

  test "PDF requires sign-in and an attested member-visible copy" do
    get print_meeting_minutes_path(@meeting)
    assert_redirected_to new_session_path

    sign_in_as(@member)
    get print_meeting_minutes_path(@meeting)
    assert_response :not_found

    @minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(
      minutes: @minutes, user: create_user("Commander", "approve_minutes"), action: "approve", evidence_note: "Synthetic handoff."
    ))
    get print_meeting_minutes_path(@meeting)
    assert_response :not_found
  end

  test "ordinary members can open the attested PDF without modifying official records" do
    attest!
    revision = @minutes.current_revision
    original_payload = revision.payload.deep_dup
    original_digest = revision.sha256
    sign_in_as(@member)
    get meeting_minutes_path(@meeting)
    assert_select "a[href='#{print_meeting_minutes_path(@meeting)}'][data-turbo=false]", text: "Open minutes PDF"

    assert_no_difference [ -> { MinutesRevision.count }, -> { MinutesAttestation.count }, -> { MinutesLifecycleEvent.count } ] do
      assert_member_pdf(revision)
    end
    assert_equal original_payload, revision.reload.payload
    assert_equal original_digest, revision.sha256
  end

  test "reopened and handed-off corrections download the attested snapshot" do
    attest!
    revision = @minutes.current_revision
    @minutes.reopen_with_confirmation!(confirmation: confirm("reopen", reason: "Correct the report."))
    @minutes.update!(title: "Private working heading")
    @item.update!(body: "Private working correction.")
    sign_in_as(@member)
    assert_member_pdf(revision)

    @minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(
      minutes: @minutes, user: create_user("Commander", "approve_minutes"), action: "approve", evidence_note: "Synthetic correction handoff."
    ))
    assert_not_equal revision.id, @minutes.current_revision_id
    assert_member_pdf(revision)
  end

  test "pending corrections retain the attested PDF until final approval locks the corrected revision" do
    attest!
    revision = @minutes.current_revision
    approving_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago, title: "Later Membership Meeting")
    @minutes.record_membership_approval_with_confirmation!(confirmation: confirm("record_membership_approval",
      approving_meeting_id: approving_meeting.id, disposition: "approved_as_corrected", corrections_pending: true, factual_note: "Correct the report."))
    @item.update!(body: "Corrected final narrative.")
    sign_in_as(@member)
    assert_member_pdf(revision)

    attest!
    assert @minutes.membership_approved?
    assert_member_pdf(@minutes.current_revision, suffix: "official-minutes")
  end

  test "PDF lookup stays in the installed organization" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_body = other.meeting_bodies.create!(name: "Membership", slug: "membership")
    other_meeting = create_meeting!(organization: other, meeting_body: other_body, starts_at: 1.day.ago)
    other_minutes = MeetingMinutes.create_from_meeting!(meeting: other_meeting)
    other_minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(
      minutes: other_minutes, user: @adjutant, action: "attest", evidence_note: "Synthetic attestation."
    ))
    sign_in_as(@member)

    get print_meeting_minutes_path(other_meeting)
    assert_response :not_found
  end

  test "generation failure returns members to the minutes with plain guidance" do
    attest!
    sign_in_as(@member)
    renderer = ->(**) { raise MeetingMinutesPdf::GenerationError, "Synthetic renderer failure" }
    with_stubbed_class_method(MeetingMinutesPdf, :render, renderer) { get print_meeting_minutes_path(@meeting) }

    assert_redirected_to meeting_minutes_path(@meeting)
    assert_equal "The minutes PDF could not be created. Try again.", flash[:alert]
  end

  private

  def create_user(label, *capabilities)
    user = User.create!(person: Person.create!(first_name: "Test", last_name: label), email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| user.permission_grants.create!(capability:) }
    user
  end

  def confirm(action, **action_payload)
    OfficialActionConfirmation.record_external!(minutes: @minutes, user: @adjutant, action:, action_payload:, evidence_note: "Synthetic officer confirmation.")
  end

  def attest!
    @minutes.reload.attest_with_confirmation!(confirmation: confirm("attest"))
  end

  def assert_member_pdf(revision, suffix: "attested-minutes")
    rendered = nil
    renderer = lambda do |minutes:, revision:|
      rendered = { minutes:, revision: }
      "%PDF-1.7\nmember minutes"
    end
    with_stubbed_class_method(MeetingMinutesPdf, :render, renderer) { get print_meeting_minutes_path(@meeting) }
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers.fetch("Content-Disposition"))
    assert_match(/recorded-membership-meeting-.*-#{suffix}\.pdf/, response.headers.fetch("Content-Disposition"))
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_equal({ minutes: @minutes, revision: }, rendered)
  end
end
