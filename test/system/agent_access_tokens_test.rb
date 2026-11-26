require "application_system_test_case"
require_relative "../support/token_clipboard_support"

class AgentAccessTokensSystemTest < ApplicationSystemTestCase
  include TokenClipboardSupport
  include ActiveJob::TestHelper
  setup do
    Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)

    system_sign_in(@user)
  end

  test "member creates, sees once, and revokes a personal agent token" do
    visit profile_path
    click_link "Manage agent access"
    click_link "New agent token"

    fill_in "Token name", with: "Grok meeting helper"
    select "30 days", from: "Expires after"
    click_button "Create token"

    assert_selector "h1", text: "Copy your agent token now"
    assert_button "Copy token"
    plaintext = find("#issued-agent-token").value
    assert_match(/\Alpt_[0-9a-f]{24}_[0-9a-f]{64}\z/, plaintext)
    assert_text "This is the only time the complete token will be shown."
    token = @user.agent_access_tokens.find_by!(name: "Grok meeting helper")
    original_token = token.attributes
    assert_token_copied_to_clipboard(plaintext)
    assert_equal original_token, token.reload.attributes

    click_link "I have stored it"
    assert_selector ".agent-token-name", text: "Grok meeting helper"
    assert_no_selector "#issued-agent-token"

    page.go_back
    assert_no_selector "#issued-agent-token"
    assert_no_text plaintext

    visit agent_access_tokens_path
    page.current_window.resize_to(390, 844)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    click_link "Revoke"
    assert_selector "h1", text: "Revoke Grok meeting helper?"
    click_button "Revoke token"

    assert_selector ".agent-token-status", text: "Revoked"
    assert_predicate @user.agent_access_tokens.last.reload, :revoked?
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "an expired form returns to the entered name and expiry after keyboard email confirmation" do
    visit new_agent_access_token_path
    assert_selector "input:focus", id: "agent_access_token_name"
    fill_in "Token name", with: "Records assistant"
    select "180 days", from: "Expires after"
    @user.sessions.sole.update!(authenticated_at: 20.minutes.ago)
    click_button "Create token"
    assert_selector ".token-setup h2", text: "New agent token"
    page.current_window.resize_to(390, 844)
    perform_enqueued_jobs do
      find_button("Email me a code").send_keys(:return)
      assert_selector "input:focus", id: "code"
    end
    assert_no_button "Create token"
    email = ActionMailer::Base.deliveries.last.text_part.body.to_s
    code = email[/\b\d{4} \d{4}\b/]
    fill_in "8-digit code", with: "bad"
    find_button("Continue").send_keys(:return)
    assert_text "Check the code or send a new one."
    fill_in "8-digit code", with: code
    find_button("Continue").send_keys(:return)
    assert_selector "input:focus", id: "agent_access_token_name"
    assert_field "Token name", with: "Records assistant"
    assert_select "Expires after", selected: "180 days"
    assert_empty @user.agent_access_tokens
    find_button("Create token").send_keys(:return)
    assert_selector "#issued-agent-token"
    assert_in_delta 180.days.from_now, @user.agent_access_tokens.sole.expires_at, 10.seconds
    page.refresh
    assert_no_selector "#issued-agent-token"
    assert_equal 1, @user.agent_access_tokens.count
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "a registered passkey continues each workspace to details before issuing the selected credential" do
    @user.permission_grants.create!(capability: "manage_settings")
    protection = ActionController::Base.allow_forgery_protection
    origins = WebAuthn.configuration.allowed_origins
    ActionController::Base.allow_forgery_protection = true
    WebAuthn.configuration.allowed_origins = [ "http://localhost:#{Capybara.current_session.server.port}" ]
    browser = page.driver.browser
    browser.execute_cdp("WebAuthn.enable")
    device = browser.execute_cdp("WebAuthn.addVirtualAuthenticator", options: {
      protocol: "ctap2", transport: "internal", hasResidentKey: true,
      hasUserVerification: true, isUserVerified: true, automaticPresenceSimulation: true
    })
    visit profile_path
    fill_in "new-passkey-nickname", with: "Test device"
    click_button "Create passkey"
    assert_selector ".pk-list input[value='Test device']"
    current_session = @user.sessions.sole

    [ [ new_agent_access_token_path, "Token name", "Create token", "agent" ],
      [ new_admin_website_access_token_path, "Connection name", "Create connection", "website" ] ].each do |path, field, action, kind|
      current_session.update!(authenticated_at: 20.minutes.ago)
      visit path
      assert_button "Use my passkey"
      [ 1400, 390 ].each do |width|
        page.current_window.resize_to(width, 844)
        assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
        capture_system_screenshot("token-confirm-#{kind}-#{width}")
      end
      assert_no_button action
      find_button("Use my passkey").send_keys(:return)
      assert_field field
      assert_equal path, page.current_path
      assert current_session.reload.recently_authenticated?
      assert_equal 0, WebsiteAccessToken.count
      assert_equal(kind == "website" ? 1 : 0, AgentAccessToken.count)
      fill_in field, with: "Synthetic #{kind}"
      find_button(action).send_keys(:return)
      assert_selector "#issued-#{kind}-token"
      page.refresh
      assert_no_selector "#issued-#{kind}-token"
    end
    assert_equal @user, AgentAccessToken.sole.user
    assert_equal @user, WebsiteAccessToken.sole.created_by
  ensure
    browser&.execute_cdp("WebAuthn.removeVirtualAuthenticator", authenticatorId: device.fetch("authenticatorId")) if device
    WebAuthn.configuration.allowed_origins = origins
    ActionController::Base.allow_forgery_protection = protection
    page.current_window.resize_to(1400, 1400)
  end
end
