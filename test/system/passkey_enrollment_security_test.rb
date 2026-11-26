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

  test "a member confirms by code and creates a named passkey from Profile at desktop and phone widths" do
    [ 1400, 390, 320 ].each do |width|
      with_device do
        page.current_window.resize_to(width, 1000)
        system_sign_in(@user)
        @user.sessions.update_all(authenticated_at: 1.hour.ago)
        visit profile_path
        fill_in "new-passkey-nickname", with: "Kitchen iPad #{width}"
        assert_text "First, confirm it’s you."
        assert_no_button "Use an existing passkey" if @user.passkey_credentials.empty?
        check_layout("profile-confirm-#{width}", stacked: width < 1400)

        count = @user.passkey_credentials.count
        perform_enqueued_jobs do
          find_button("Email me a code").send_keys(:return)
          assert_selector "#code:focus"
        end
        assert_current_path profile_path
        check_layout("profile-code-#{width}", stacked: width < 1400)
        fill_in "8-digit code", with: "bad"
        click_button "Continue"
        assert_selector "#add-passkey [role=alert]", text: "Check the code"
        fill_in "8-digit code", with: ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]
        find_button("Continue").send_keys(:return)
        assert_current_path profile_path
        assert_text "You’re ready to add your passkey."
        assert_selector "#add-passkey button:focus", text: "Create passkey"
        assert_field "new-passkey-nickname", with: "Kitchen iPad #{width}"
        assert_equal count, @user.passkey_credentials.count
        check_layout("profile-ready-#{width}", stacked: width < 1400)

        find_button("Create passkey").send_keys(:return)
        assert_text "Passkey added: Kitchen iPad #{width}"
        visit profile_path
        assert_selector ".saved-passkeys input[value='Kitchen iPad #{width}']"
        assert_equal count + 1, @user.passkey_credentials.count
      end
    end
  end

  test "dashboard email link returns to device setup and the saved passkey signs in" do
    with_device do
      page.current_window.resize_to(390, 844)
      system_sign_in(@user)
      @user.sessions.sole.update!(authenticated_at: 1.hour.ago)
      visit root_path
      fill_in "new-passkey-nickname", with: "My phone"
      perform_enqueued_jobs do
        click_button "Email me a code"
        assert_field "8-digit code"
      end
      email_link = ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{https?://\S+}]
      visit URI(email_link).request_uri
      assert_button "Continue setup"
      assert_button "Cancel"
      capture_system_screenshot("email-link-390")
      assert_not @user.sessions.sole.recently_authenticated?
      click_button "Continue setup"
      assert_current_path root_path
      assert_field "new-passkey-nickname", with: "My phone"
      assert_selector "#add-passkey button:focus", text: "Create passkey"
      assert_equal 0, @user.passkey_credentials.count
      assert page.evaluate_script("document.activeElement.getBoundingClientRect().bottom <= window.innerHeight")
      check_layout("dashboard-ready-390", stacked: true)
      click_button "Create passkey"
      assert_text "Passkey added: My phone"
      assert_no_selector "#add-passkey"
      find(".app-menu-btn").click
      click_button "Sign out"
      click_button "Sign in with a passkey"
      assert_selector ".app-menu-btn"
      visit profile_path
      assert_selector ".saved-passkeys input[value='My phone']"
      assert @user.passkey_credentials.sole.last_used_at
    end
  end

  test "a recent dashboard sign-in can cancel the device prompt and retry, then confirm an additional passkey" do
    system_sign_in(@user)
    with_device do
      visit root_path
      fill_in "new-passkey-nickname", with: "First device"
      page.execute_script(<<~JS)
        const original = navigator.credentials.create.bind(navigator.credentials)
        navigator.credentials.create = (...args) => {
          navigator.credentials.create = original
          return Promise.reject(new DOMException("User cancelled", "NotAllowedError"))
        }
      JS
      click_button "Create passkey"
      assert_selector "[role=status]", text: "Passkey setup was cancelled."
      assert_field "new-passkey-nickname", with: "First device"
      assert_button "Not now"
      assert_equal 0, @user.passkey_credentials.count
      click_button "Try again"
      assert_text "Passkey added: First device"

      @user.sessions.sole.update!(authenticated_at: 1.hour.ago)
      visit profile_path
      fill_in "new-passkey-nickname", with: "Second device"
      click_button "Use an existing passkey"
      assert_text "You’re ready to add your passkey."
      assert_field "new-passkey-nickname", with: "Second device"
      assert_equal 1, @user.passkey_credentials.count
    end
    with_device do
      click_button "Create passkey"
      assert_text "Passkey added: Second device"
      assert_equal [ "First device", "Second device" ], @user.passkey_credentials.order(:id).pluck(:nickname)
    end
  end

  test "a sign-in that ages out during entry keeps the dashboard name until cancellation" do
    system_sign_in(@user)
    visit root_path
    fill_in "new-passkey-nickname", with: "Desk phone"
    @user.sessions.sole.update!(authenticated_at: 1.hour.ago)
    click_button "Create passkey"
    assert_current_path root_path
    assert_text "First, confirm it’s you."
    assert_field "new-passkey-nickname", with: "Desk phone"
    assert_button "Email me a code"
    assert_no_button "Use an existing passkey"
    click_button "Cancel"
    assert_current_path root_path
    assert_field "new-passkey-nickname", with: ""
    assert_button "Not now"
    assert_equal 0, @user.passkey_credentials.count
  end

  test "an unsupported browser explains email sign-in and leaves the invitation dismissible" do
    system_sign_in(@user)
    browser = page.driver.browser
    script = browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: "window.PublicKeyCredential = undefined")
    visit root_path
    assert_text "This browser can’t add a passkey. You can still sign in by email."
    assert_no_button "Create passkey"
    assert_button "Not now"
    assert_link "Browse all meetings"
    click_button "Not now"
    assert_no_selector "#add-passkey"
  ensure
    browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: script.fetch("identifier")) if script
  end

  private

  def with_device
    browser = page.driver.browser
    browser.execute_cdp("WebAuthn.enable")
    device = browser.execute_cdp("WebAuthn.addVirtualAuthenticator", options: {
      protocol: "ctap2", transport: "internal", hasResidentKey: true,
      hasUserVerification: true, isUserVerified: true, automaticPresenceSimulation: true
    })
    yield
  ensure
    browser.execute_cdp("WebAuthn.removeVirtualAuthenticator", authenticatorId: device.fetch("authenticatorId")) if device
  end

  def check_layout(name, stacked:)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    assert_operator page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.enrollment-instruction')).fontSize)"), :>=, 16
    field = find(".enrollment-row .f").native.rect
    action = find(".enrollment-methods .btn-primary").native.rect
    if stacked
      assert_in_delta field.x, action.x, 1
      assert_in_delta field.width, action.width, 1
    else
      assert_in_delta field.y, action.y, 1
      assert_in_delta field.height, action.height, 1
    end
    capture_system_screenshot(name)
  end
end
