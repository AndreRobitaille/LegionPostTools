require "application_system_test_case"

class WebsiteAccessTokensSystemTest < ApplicationSystemTestCase
  setup do
    Organization.create!(name: "Synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @admin = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Administrator"), email_address: "website-admin@example.test")
    @admin.permission_grants.create!(capability: "manage_settings")
    system_sign_in(@admin)
  end

  test "administrator creates copies and revokes a Post website connection at desktop and narrow widths" do
    visit admin_root_path
    click_link "Manage website connections"
    assert_text "No website connections yet"
    capture_layout("empty")
    click_link "Create website connection"
    assert_text "not your personal account"
    capture_layout("new")
    fill_in "Connection name", with: "Post public website"
    click_button "Create token"
    assert_selector "h1", text: "Copy your website token now"
    assert_button "Copy token"
    secret = find("#issued-website-token").value
    assert_match(/\Alptw_[0-9a-f]{24}_[0-9a-f]{64}\z/, secret)
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

  private

  def capture_layout(name)
    [ [ 1400, 1400 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth"), "Overflow on #{name} at #{width}px"
      page.save_screenshot(Rails.root.join("tmp/screenshots/website-#{name}-#{width}.png"))
    end
  end
end
