require "test_helper"

class OfficialActionReauthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(
      organization:,
      meeting_body: body,
      starts_at: 1.day.ago,
      title: "August Membership"
    )
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    person = Person.create!(first_name: "Test", last_name: "Commander")
    @user = User.create!(person:, email_address: "commander@example.com", email_verified_at: Time.current)
    @user.permission_grants.create!(capability: "approve_minutes")
    @session_record = sign_in_as(@user, authenticated_at: 1.hour.ago)

    post admin_meeting_minutes_approval_path(@meeting)
    @confirmation = OfficialActionConfirmation.last
  end

  test "email code confirms and completes the exact pending approval" do
    assert_redirected_to new_official_action_reauthentication_path

    perform_enqueued_jobs { post official_action_reauthentication_path }
    challenge = MagicLink.order(:created_at).last
    assert_equal "official_minutes_action", challenge.purpose
    assert_equal @session_record, challenge.session

    delivered_email = ActionMailer::Base.deliveries.last
    code = delivered_email.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    post verify_official_action_reauthentication_path, params: { code: }

    assert_redirected_to new_admin_meeting_minutes_approval_path(@meeting, confirmation_id: @confirmation.id)
    assert @confirmation.reload.confirmed_at
    assert_operator @session_record.reload.authenticated_at, :>, 1.minute.ago

    post admin_meeting_minutes_approval_path(@meeting), params: { confirmation_id: @confirmation.id }

    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_equal "approved", @minutes.reload.status
    assert @confirmation.reload.consumed_at
  end

  test "the confirmation page describes the exact action and digest" do
    get new_official_action_reauthentication_path

    assert_response :success
    assert_select "h2", text: "Approve for Adjutant attestation"
    assert_select "code", text: @confirmation.content_digest.first(12)
    assert_select "form[action=?] button", official_action_reauthentication_path,
      text: "Email me a code and link"
  end
end
