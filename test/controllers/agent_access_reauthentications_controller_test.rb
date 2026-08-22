require "test_helper"

class AgentAccessReauthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Doe"), email_address: "jane@example.com")
    @session_record = sign_in_as(@user, authenticated_at: 1.hour.ago)
  end

  test "email code reauthentication refreshes the same session" do
    perform_enqueued_jobs { post agent_access_reauthentication_path }

    challenge = MagicLink.order(:created_at).last
    assert_equal "create_agent_access_token", challenge.purpose
    assert_equal @session_record, challenge.session

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal "Confirm agent access in LegionPostTools", delivered_email.subject
    assert_no_match(/sign[ -]in link/i, delivered_email.html_part.body.to_s)
    code = delivered_email.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    post verify_agent_access_reauthentication_path, params: { code: code }

    assert_redirected_to new_agent_access_token_path
    assert_operator @session_record.reload.authenticated_at, :>, 1.minute.ago
    assert_equal 1, Session.where(user: @user).count
  end

  test "sign-in code cannot be used for token reauthentication" do
    sign_in_challenge = MagicLink.create_for!(@user)
    perform_enqueued_jobs { post agent_access_reauthentication_path }

    post verify_agent_access_reauthentication_path, params: { code: sign_in_challenge.login_code }

    assert_redirected_to new_agent_access_reauthentication_path
    assert_operator @session_record.reload.authenticated_at, :<, 10.minutes.ago
  end

  test "bearer authentication cannot enter reauthentication flow" do
    _token, plaintext = AgentAccessToken.issue!(user: @user, name: "Grok", expires_in: 30.days)

    open_session do |agent_client|
      agent_client.get new_agent_access_reauthentication_path, headers: { "Authorization" => "Bearer #{plaintext}" }
      assert_equal 302, agent_client.response.status
      assert_equal new_session_url, agent_client.response.location
    end
  end
end
