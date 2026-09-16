require "application_system_test_case"

class PasskeyEnrollmentSecuritySystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @original_capybara_settings = [ Capybara.server_host, Capybara.app_host ]
    Capybara.server_host = "0.0.0.0"
    # Other system tests may already have started the shared application server.
    Capybara.app_host = "http://localhost:#{Capybara.current_session.server.port}"
    @original_origins = WebAuthn.configuration.allowed_origins
    WebAuthn.configuration.allowed_origins = [ Capybara.app_host ]
    Organization.create!(name: "Enrollment Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Enrollment", last_name: "Member"),
      email_address: "enrollment-browser@example.com", email_verified_at: Time.current)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_forgery_protection
    WebAuthn.configuration.allowed_origins = @original_origins
    Capybara.server_host, Capybara.app_host = @original_capybara_settings
  end

  test "confirmation preserves the name and completes enrollment at desktop and narrow widths" do
    page.driver.browser.execute_cdp("WebAuthn.enable")
    [ 1400, 390, 320 ].each do |width|
      authenticator = page.driver.browser.execute_cdp("WebAuthn.addVirtualAuthenticator", options: {
        protocol: "ctap2", transport: "internal", hasResidentKey: true,
        hasUserVerification: true, isUserVerified: true, automaticPresenceSimulation: true
      })
      page.driver.browser.manage.window.resize_to(width, 1000)
      system_sign_in(@user)
      @user.sessions.update_all(authenticated_at: 1.hour.ago)
      visit profile_path
      fill_in "new-passkey-nickname", with: "Kitchen iPad #{width}"
      click_button "Add a passkey"
      assert_current_path new_passkey_enrollment_reauthentication_path
      assert_text "Before adding a new passkey, confirm it’s you"
      assert_button "Cancel and return to Profile"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      assert_operator page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.page-lead .panel-lead')).fontSize)"), :>=, 16
      page.save_screenshot(Rails.root.join("tmp", "passkey-confirmation-#{width}.png"))

      perform_enqueued_jobs do
        click_button "Email me a code and link"
        assert_field "8-digit confirmation code"
      end
      email = ActionMailer::Base.deliveries.last
      code = email.text_part.body.to_s[/\b\d{4} \d{4}\b/]
      assert code.present?
      fill_in "8-digit confirmation code", with: code
      click_button "Confirm identity"
      assert_current_path profile_path
      assert_equal "#add-passkey", page.evaluate_script("window.location.hash")
      assert_field "new-passkey-nickname", with: "Kitchen iPad #{width}"
      assert_button "Continue adding your passkey"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      page.save_screenshot(Rails.root.join("tmp", "passkey-continue-#{width}.png"))

      click_button "Continue adding your passkey"
      assert_button "Add a passkey"
      assert_field "new-passkey-nickname", with: ""
      assert @user.passkey_credentials.exists?(nickname: "Kitchen iPad #{width}")
      page.driver.browser.execute_cdp("WebAuthn.removeVirtualAuthenticator", authenticatorId: authenticator.fetch("authenticatorId"))
    end
  end
end
