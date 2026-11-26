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
    assert_redirected_to new_agent_access_token_path
    follow_redirect!
    assert_response :success
    assert_select "form[action=?] button", agent_access_reauthentication_path(kind: "agent"),
      text: "Email me a code"
    assert_select ".token-setup", text: /Confirm it’s you to continue/
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

    assert_redirected_to new_agent_access_token_path
    assert_equal "We could not send that email. Try again in a few minutes.", flash[:alert]
  ensure
    MailDelivery.backend = original_backend
  end

  test "email link reauthentication confirms before refreshing the same session" do
    perform_enqueued_jobs { post agent_access_reauthentication_path }
    challenge = MagicLink.order(:created_at).last
    token = ActionMailer::Base.deliveries.last.html_part.body.to_s[/token=([A-Za-z0-9_-]+)/, 1]
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
    token = ActionMailer::Base.deliveries.last.html_part.body.to_s[/token=([A-Za-z0-9_-]+)/, 1]
    assert token.present?

    open_session do |other_browser|
      other_session = Session.create!(user: @user, authenticated_at: 1.hour.ago, last_seen_at: Time.current)
      jar = ActionDispatch::TestRequest.create.cookie_jar
      jar.signed[:session_id] = other_session.id
      other_browser.cookies[:session_id] = jar["session_id"]
      other_browser.post magic_link_agent_access_reauthentication_path, params: { token: token }
      assert_equal 302, other_browser.response.status
      assert_equal new_agent_access_token_url, other_browser.response.location
    end

    assert_nil challenge.reload.used_at
  end

  test "sign-in code cannot be used for token reauthentication" do
    sign_in_challenge = MagicLink.create_for!(@user)
    perform_enqueued_jobs { post agent_access_reauthentication_path }

    post verify_agent_access_reauthentication_path, params: { code: sign_in_challenge.login_code }

    assert_redirected_to new_agent_access_token_path
    assert_operator @session_record.reload.authenticated_at, :<, 10.minutes.ago
  end

  test "resend and cancel retire the email link and clear only that credential's draft" do
    @user.permission_grants.create!(capability: "manage_settings")
    post agent_access_tokens_path, params: { agent_access_token: { name: "Agent A", expires_in_days: "180" } }
    post admin_website_access_tokens_path, params: { website_access_token: { name: "Website B" } }

    assert_no_difference [ "AgentAccessToken.count", "WebsiteAccessToken.count" ] do
      old_link = request_email_link("website")
      current_link = request_email_link("website")
      agent_link = request_email_link("agent")
      post old_link
      assert_not @session_record.reload.recently_authenticated?
      get current_link
      assert_select "h1", text: "Website connections"
      assert_select ".agent-access-section", text: /Existing connections/
      assert_select "button", text: "Continue to connection details"
      assert_not @session_record.reload.recently_authenticated?
      delete agent_access_reauthentication_path(kind: "website")
      assert_redirected_to admin_website_access_tokens_path
      post current_link
      assert_not @session_record.reload.recently_authenticated?
      get agent_link
      assert_select "h1", text: "Agent access"
      assert_select ".agent-access-section", text: /Your agent tokens/
      assert_select "button", text: "Continue to token details"
      post agent_link
      assert_redirected_to new_agent_access_token_path
      follow_redirect!
      assert_select "input[value='Agent A'][autofocus]"
      assert_select "option[value='180'][selected]"
      get new_admin_website_access_token_path
      assert_select "input[value='Website B']", count: 0
    end
  end

  test "an expired code returns to confirmation choices and a fresh code can resume setup" do
    request_email_link("agent")
    travel MagicLink::TOKEN_TTL + 1.second do
      get new_agent_access_token_path
      assert_select "button", text: "Email me a code"
      assert_select "input[name=code]", count: 0
      assert_no_difference "AgentAccessToken.count" do
        link = request_email_link("agent")
        post link
        follow_redirect!
        assert_select "input[name='agent_access_token[name]'][autofocus]"
      end
    end
  end

  test "website confirmation and final creation require the administrator's current grant" do
    grant = @user.permission_grants.create!(capability: "manage_settings")
    link = request_email_link("website")
    grant.destroy!
    assert_no_difference [ "AgentAccessToken.count", "WebsiteAccessToken.count" ] do
      post link
      assert_redirected_to root_path
      assert_not @session_record.reload.recently_authenticated?
      post passkey_options_agent_access_reauthentication_path(kind: "website"), as: :json
      assert_redirected_to root_path
      @session_record.reauthenticate!
      post admin_website_access_tokens_path, params: { website_access_token: { name: "Website" } }
      assert_redirected_to root_path
    end
  end

  test "bearer authentication cannot enter reauthentication flow" do
    _token, plaintext = AgentAccessToken.issue!(user: @user, name: "Grok", expires_in: 30.days)

    open_session do |agent_client|
      agent_client.get new_agent_access_reauthentication_path, headers: { "Authorization" => "Bearer #{plaintext}" }
      assert_equal 302, agent_client.response.status
      assert_equal new_session_url, agent_client.response.location
    end
  end
  private

  def request_email_link(kind)
    perform_enqueued_jobs { post agent_access_reauthentication_path(kind:) }
    URI(ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{https?://\S+}]).request_uri
  end
end
