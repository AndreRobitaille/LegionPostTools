require "application_system_test_case"

class AuthenticationEntrySystemTest < ApplicationSystemTestCase
  include ActionMailer::TestHelper

  setup do
    Organization.create!(name: "Test American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Member"), email_address: "jane@example.com")
  end

  test "sign-in bookmarks and old emails take a signed-in member to the dashboard" do
    system_sign_in(@user)
    existing_session = @user.sessions.sole
    expired_link = MagicLink.create_for!(@user)
    expired_link.update!(expires_at: 1.day.ago)

    [ new_session_path, code_session_path, magic_link_session_path(token: expired_link.token) ].each do |path|
      visit path
      assert_current_path root_path
      assert_selector ".app-menu-btn", text: "Menu"
      assert_no_button "Send my sign-in email"
    end

    assert_equal existing_session, @user.sessions.sole
    assert_nil expired_link.reload.used_at

    click_button "Menu"
    click_button "Sign out"
    assert_current_path new_session_path
    assert_button "Send my sign-in email"
  end

  test "a member can request another email and sign in with the newest code at phone width" do
    page.driver.browser.manage.window.resize_to(390, 900)
    visit new_session_path
    request_sign_in_email
    first_challenge = @user.magic_links.sole

    assert_text "No email? Check Spam or Junk."
    assert_text "Enter the code from your newest email."
    click_link "Request another email"
    assert_current_path new_session_path
    request_sign_in_email

    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    assert code
    fill_in "8-digit sign-in code", with: code
    click_button "Finish signing in"

    assert_current_path root_path
    assert_selector ".app-menu-btn", text: "Menu"
    assert_nil first_challenge.reload.used_at
    assert @user.magic_links.order(:created_at).last.used_at
    assert_equal 1, @user.sessions.count

    visit new_session_path
    assert_current_path root_path
    assert_no_button "Send my sign-in email"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  private

  def request_sign_in_email
    fill_in "Email address", with: @user.email_address
    assert_emails 1 do
      click_button "Send my sign-in email"
      assert_current_path code_session_path
      assert_field "8-digit sign-in code"
    end
  end
end
