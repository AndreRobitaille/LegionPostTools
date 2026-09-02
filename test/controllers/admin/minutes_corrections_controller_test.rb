require "test_helper"

class Admin::MinutesCorrectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Legion Hall",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @minutes_meeting = create_meeting!(
      organization: @organization,
      meeting_body: @body,
      starts_at: 2.months.ago,
      title: "July Membership Meeting"
    )
    @approving_meeting = create_meeting!(
      organization: @organization,
      meeting_body: @body,
      starts_at: 1.day.ago,
      title: "September Membership Meeting"
    )
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @minutes_meeting)
    @commander = create_user("Commander", "approve_minutes", "record_minutes_approval")
    @adjutant = create_user("Adjutant", "manage_minutes", "attest_minutes", "record_minutes_approval")
    approve_and_attest!
  end

  test "Adjutant can prepare and complete an audited reopening" do
    session_record = sign_in_as(@adjutant)

    get new_admin_meeting_minutes_reopening_path(@minutes_meeting)
    assert_response :success
    assert_select "h1", text: "Reopen this exact revision"
    assert_select ".official-confirmation-summary", text: /does not record or repeat a membership vote/i

    assert_difference -> { OfficialActionConfirmation.count }, 1 do
      post admin_meeting_minutes_reopening_path(@minutes_meeting), params: {
        minutes_reopening: { reason: "Incorporate the correction adopted during membership approval." }
      }
    end

    confirmation = OfficialActionConfirmation.last
    assert_redirected_to new_official_action_reauthentication_path
    assert_equal "reopen", confirmation.action
    assert_equal "Incorporate the correction adopted during membership approval.", confirmation.action_payload.fetch("reason")
    confirmation.update!(confirmed_at: Time.current)

    post admin_meeting_minutes_reopening_path(@minutes_meeting), params: { confirmation_id: confirmation.id }

    assert_redirected_to admin_meeting_minutes_path(@minutes_meeting)
    assert_predicate @minutes.reload, :reopened?
    assert_equal session_record, confirmation.session
    assert_equal "reopened", @minutes.lifecycle_events.last.event_type
  end

  test "Commander can record membership approval of an attested exact revision" do
    sign_in_as(@commander)

    get new_admin_meeting_minutes_membership_approval_path(@minutes_meeting)
    assert_response :success
    assert_select "h1", text: "Record the membership's approval"
    approval_date = @approving_meeting.starts_at.to_date.strftime("%d %b %Y").upcase
    assert_select "option", text: "Membership — #{approval_date}"
    assert_select "label", text: /Approved as corrected/

    post admin_meeting_minutes_membership_approval_path(@minutes_meeting), params: {
      minutes_membership_approval: {
        approving_meeting_id: @approving_meeting.id,
        disposition: "approved_as_corrected"
      }
    }
    confirmation = OfficialActionConfirmation.last
    assert_redirected_to new_official_action_reauthentication_path
    assert_equal "record_membership_approval", confirmation.action
    confirmation.update!(confirmed_at: Time.current)

    post admin_meeting_minutes_membership_approval_path(@minutes_meeting), params: { confirmation_id: confirmation.id }

    assert_redirected_to admin_meeting_minutes_path(@minutes_meeting)
    assert_predicate @minutes.reload, :membership_approved?
    assert_equal "approved_as_corrected", @minutes.membership_approval.disposition
    assert_equal @approving_meeting, @minutes.membership_approval.approving_meeting
  end

  test "draft minutes remain on the ordinary September workflow" do
    september_minutes = MeetingMinutes.create_from_meeting!(meeting: @approving_meeting)
    sign_in_as(@commander)

    get admin_meeting_minutes_path(@approving_meeting)

    assert_response :success
    assert_select "a", text: "Approve exact draft for Adjutant"
    assert_select "a", text: "Record membership approval", count: 0
    assert_predicate september_minutes, :draft?
  end

  private

  def approve_and_attest!
    @minutes.approve_with_confirmation!(
      confirmation: OfficialActionConfirmation.record_external!(
        minutes: @minutes,
        user: @commander,
        action: "approve",
        evidence_note: "Commander supplied written approval."
      )
    )
    @minutes.attest_with_confirmation!(
      confirmation: OfficialActionConfirmation.record_external!(
        minutes: @minutes,
        user: @adjutant,
        action: "attest",
        evidence_note: "Adjutant supplied written attestation."
      )
    )
  end

  def create_user(label, *capabilities)
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person:, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| user.permission_grants.create!(capability:) }
    user
  end
end
