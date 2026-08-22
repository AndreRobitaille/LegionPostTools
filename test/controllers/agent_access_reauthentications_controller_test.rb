require "test_helper"

class AgentAccessReauthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Doe"), email_address: "jane@example.com")
    @session_record = sign_in_as(@user, authenticated_at: 1.hour.ago)
  end

  test "request page describes the consolidated code and link email" do
    get new_agent_access_reauthentication_path

    assert_response :success
    assert_select "form[action=?] button", agent_access_reauthentication_path,
      text: "Email me a code and link"
    assert_select ".panel-lead", text: /code and secure link/
  end

  test "email code reauthentication refreshes the same session" do
    perform_enqueued_jobs { post agent_access_reauthentication_path }

    challenge = MagicLink.order(:created_at).last
    assert_equal "create_agent_access_token", challenge.purpose
    assert_equal @session_record, challenge.session

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal "Your LegionPostTools code and link", delivered_email.subject
    assert_match(/continue/i, delivered_email.html_part.body.to_s)
    assert_match(%r{/agent_access_reauthentication/magic_link}, delivered_email.html_part.body.to_s)
    code = delivered_email.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    post verify_agent_access_reauthentication_path, params: { code: code }

    assert_redirected_to new_agent_access_token_path
    assert_operator @session_record.reload.authenticated_at, :>, 1.minute.ago
    assert_equal 1, Session.where(user: @user).count
  end

  test "provider failure gives a signed-in user an actionable error" do
    failing_backend = Object.new
    failing_backend.define_singleton_method(:deliver_magic_link) do |**|
      raise MailDelivery::DeliveryError.new("Provider unavailable", status: 503)
    end
    original_backend = MailDelivery.backend
    MailDelivery.backend = failing_backend

    post agent_access_reauthentication_path

    assert_redirected_to new_agent_access_reauthentication_path
    assert_equal "We could not send that email. Try again in a few minutes.", flash[:alert]
  ensure
    MailDelivery.backend = original_backend
  end

  test "email link reauthentication confirms before refreshing the same session" do
    perform_enqueued_jobs { post agent_access_reauthentication_path }
    challenge = MagicLink.order(:created_at).last
    token = ActionMailer::Base.deliveries.last.html_part.body.to_s[%r{magic_link\?token=([^"<]+)}, 1]
    assert token.present?

    get magic_link_agent_access_reauthentication_path(token: token)

    assert_response :success
    assert_select "form[action=?][method=post]", magic_link_agent_access_reauthentication_path
    assert_nil challenge.reload.used_at

    post magic_link_agent_access_reauthentication_path, params: { token: token }

    assert_redirected_to new_agent_access_token_path
    assert_operator @session_record.reload.authenticated_at, :>, 1.minute.ago
    assert challenge.reload.used_at
    assert_nil MagicLink.consume_code!(
      browser_challenge: challenge.browser_challenge,
      code: challenge.login_code,
      purpose: "create_agent_access_token",
      session: @session_record
    )
    assert_equal 1, Session.where(user: @user).count
  end

  test "email link reauthentication rejects a different signed-in session" do
    perform_enqueued_jobs { post agent_access_reauthentication_path }
    challenge = MagicLink.order(:created_at).last
    token = ActionMailer::Base.deliveries.last.html_part.body.to_s[%r{magic_link\?token=([^"<]+)}, 1]
    assert token.present?

    open_session do |other_browser|
      other_session = Session.create!(user: @user, authenticated_at: 1.hour.ago, last_seen_at: Time.current)
      jar = ActionDispatch::TestRequest.create.cookie_jar
      jar.signed[:session_id] = other_session.id
      other_browser.cookies[:session_id] = jar["session_id"]
      other_browser.post magic_link_agent_access_reauthentication_path, params: { token: token }
      assert_equal 302, other_browser.response.status
      assert_equal new_agent_access_reauthentication_url, other_browser.response.location
    end

    assert_nil challenge.reload.used_at
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
