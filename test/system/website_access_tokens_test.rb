require "application_system_test_case"
require_relative "../support/token_clipboard_support"

class WebsiteAccessTokensSystemTest < ApplicationSystemTestCase
  include TokenClipboardSupport
  include ActiveJob::TestHelper
  setup do
    Organization.create!(name: "Synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @admin = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Administrator"), email_address: "website-admin@example.test")
    @admin.permission_grants.create!(capability: "manage_settings")
    system_sign_in(@admin)
  end

  test "administrator creates views once and revokes a Post website connection at desktop and narrow widths" do
    visit admin_root_path
    click_link "Website connections", exact: false
    assert_text "No website connections yet"
    capture_layout("empty")
    click_link "New website connection"
    assert_text "Your website will be able to read approved public content."
    capture_layout("new")
    fill_in "Connection name", with: "Post public website"
    click_button "Create connection"
    assert_current_path admin_website_access_tokens_path
    assert_selector "h1", text: "Copy your website token now"
    assert_button "Copy token"
    secret = find("#issued-website-token").value
    assert_match(/\Alptw_[0-9a-f]{24}_[0-9a-f]{64}\z/, secret)
    token = WebsiteAccessToken.find_by!(name: "Post public website")
    original_token = token.attributes
    assert_token_copied_to_clipboard(secret)
    assert_equal original_token, token.reload.attributes
    # Hide only synthetic secret bytes in screenshots, preserving layout.
    page.execute_script("document.querySelector('#issued-website-token').value = 'lptw_' + 'x'.repeat(24) + '_' + 'x'.repeat(64)")
    capture_layout("created")
    click_link "I have stored it"
    assert_selector ".agent-token-name", text: "Post public website"
    capture_layout("list")
    page.go_back
    assert_no_selector "#issued-website-token"
    assert_no_text secret
    visit admin_website_access_tokens_path
    page.current_window.resize_to(390, 844)
    find("a[aria-label='Revoke Post public website']").click
    assert_selector "h1", text: "Revoke Post public website?"
    click_button "Revoke token"
    assert_selector ".agent-token-status", text: /Revoked/
    assert_nil WebsiteAccessToken.authenticate(secret)
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "a same-browser email link returns to the saved connection before it can be created" do
    page.current_window.resize_to(390, 844)
    visit new_admin_website_access_token_path
    fill_in "Connection name", with: "Post site"
    @admin.sessions.sole.update!(authenticated_at: 12.minutes.ago)
    find_button("Create connection").send_keys(:return)
    assert_text "Confirm it’s you to continue."
    perform_enqueued_jobs do
      find_button("Email me a code").send_keys(:return)
      assert_field "8-digit code"
    end
    url = ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{https?://\S+}]
    visit URI(url).request_uri
    assert_selector "h2", text: "New website connection"
    assert_equal 0, WebsiteAccessToken.count
    assert_not @admin.sessions.sole.recently_authenticated?
    find_button("Continue to connection details").send_keys(:return)
    assert_current_path new_admin_website_access_token_path
    assert_field "Connection name", with: "Post site"
    assert_equal 0, WebsiteAccessToken.count
    assert_equal 0, AgentAccessToken.count
    find_button("Create connection").send_keys(:return)
    assert_selector "#issued-website-token"
    assert_equal "Post site", WebsiteAccessToken.sole.name
    page.refresh
    assert_no_selector "#issued-website-token"
    assert_equal 1, WebsiteAccessToken.count
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def capture_layout(name)
    [ [ 1400, 1400 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth"), "Overflow on #{name} at #{width}px"
      capture_system_screenshot("website-#{name}-#{width}")
    end
  end
end
