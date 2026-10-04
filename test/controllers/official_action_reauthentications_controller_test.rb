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

    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert @confirmation.reload.confirmed_at
    assert_operator @session_record.reload.authenticated_at, :>, 1.minute.ago

    assert_equal "approved", @minutes.reload.status
    assert @confirmation.reload.consumed_at
  end

  test "email link GET explains the action and only its confirmation POST completes it" do
    challenge = MagicLink.create_for!(@user, purpose: "official_minutes_action", session: @session_record)

    get magic_link_official_action_reauthentication_path(token: challenge.token)

    assert_response :success
    assert_select "h2", text: "Send to Adjutant"
    assert_select "form button", text: "Confirm and complete"
    assert_predicate @minutes.reload, :draft?
    assert_nil @confirmation.reload.confirmed_at
    assert_nil challenge.reload.used_at

    post magic_link_official_action_reauthentication_path, params: { token: challenge.token }

    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_predicate @minutes.reload, :approved?
    assert @confirmation.reload.consumed_at
    assert challenge.reload.used_at
  end

  test "the confirmation page names the action that authentication will complete" do
    get new_official_action_reauthentication_path

    assert_response :success
    assert_select "h2", text: "Send to Adjutant"
    assert_select ".page-sub", text: /complete the action/
    assert_select "code", count: 0
    assert_select "form[action=?] button", official_action_reauthentication_path,
      text: "Email me a code and link"
  end

  test "identity confirmation rejects changed minutes instead of completing a stale handoff" do
    perform_enqueued_jobs { post official_action_reauthentication_path }
    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    @minutes.sections.first.items.create!(title: "Changed during confirmation", behavior_type: "report_slot", position: 1)

    post verify_official_action_reauthentication_path, params: { code: }

    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_match(/changed/, flash[:alert])
    assert_predicate @minutes.reload, :draft?
    assert_nil @confirmation.reload.consumed_at
    assert_empty @minutes.revisions
  end

  test "passkey confirmation completes the exact handoff and returns its workspace" do
    get new_official_action_reauthentication_path
    credential = Struct.new(:id, :sign_count) do
      def verify(*) = true
    end.new("synthetic-official-passkey", 1)
    stored = @user.passkey_credentials.create!(external_id: credential.id, public_key: "synthetic-key", sign_count: 0)
    with_stubbed_class_method(WebAuthn::Credential, :from_get, ->(*) { credential }) do
      post authentication_passkeys_path, params: { publicKeyCredential: { id: credential.id } }, as: :json
    end

    assert_response :success
    assert_equal admin_meeting_minutes_path(@meeting), response.parsed_body.fetch("redirect_url")
    assert_predicate @minutes.reload, :approved?
    assert @confirmation.reload.consumed_at
    assert_equal 1, stored.reload.sign_count
    assert_equal 1, @minutes.revisions.count
  end

  test "Adjutant email confirmation attests a draft without Commander handoff or another click" do
    @user.permission_grants.create!(capability: "attest_minutes")
    post admin_meeting_minutes_attestation_path(@meeting)
    attestation_confirmation = OfficialActionConfirmation.last
    assert_equal "attest", attestation_confirmation.action
    perform_enqueued_jobs { post official_action_reauthentication_path }
    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]

    post verify_official_action_reauthentication_path, params: { code: }

    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_predicate @minutes.reload, :attested?
    assert_nil @minutes.current_revision.approved_by_id
    assert attestation_confirmation.reload.consumed_at
  end

  test "signing out with a pending official action clears authentication and preserves the confirmation" do
    challenge = MagicLink.create_for!(@user, purpose: "official_minutes_action", session: @session_record)
    other_session = Session.create!(user: @user, authenticated_at: Time.current)
    other_confirmation = OfficialActionConfirmation.prepare!(minutes: @minutes, user: @user, session: other_session, action: "approve")
    stale_cookie = cookies[:session_id]

    assert_difference -> { Session.count }, -1 do
      delete session_path
    end

    assert_redirected_to new_session_path
    assert_equal "You are signed out.", flash[:notice]
    assert_nil Current.session
    assert cookies[:session_id].blank?
    assert_nil @confirmation.reload.session_id
    assert_nil challenge.reload.session_id
    assert_equal other_session, other_confirmation.reload.session

    cookies[:session_id] = stale_cookie
    get admin_meeting_minutes_path(@meeting)
    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?

    assert_no_difference -> { Session.count } do
      delete session_path
    end
    assert_redirected_to new_session_path
  end

  test "disabled accounts with official action confirmations lose their session without an error" do
    @user.update!(disabled_at: Time.current)

    assert_difference -> { Session.count }, -1 do
      get new_session_path
    end

    assert_response :success
    assert_nil Current.session
    assert cookies[:session_id].blank?
    assert_nil @confirmation.reload.session_id
  end

  test "inactive sessions with official action confirmations expire without an error" do
    @session_record.update!(last_seen_at: 181.days.ago)

    assert_difference -> { Session.count }, -1 do
      get new_session_path
    end

    assert_response :success
    assert_nil Current.session
    assert cookies[:session_id].blank?
    assert_nil @confirmation.reload.session_id
  end
end
