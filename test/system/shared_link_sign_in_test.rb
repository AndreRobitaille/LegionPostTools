require "application_system_test_case"

class SharedLinkSignInSystemTest < ApplicationSystemTestCase
  include ActionMailer::TestHelper

  setup do
    @original_identity = Rails.application.config.x.members_site
    Rails.application.config.x.members_site = MembersSite.new(YAML.safe_load_file(Rails.root.join("config/deploy.yml")).fetch("env").fetch("clear"))
    @original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @original_app_host = Capybara.app_host
    Capybara.app_host = "http://localhost:#{Capybara.current_session.server.port}"
    @original_origins = WebAuthn.configuration.allowed_origins
    WebAuthn.configuration.allowed_origins = [ Capybara.app_host ]
    organization = Organization.create!(name: "Synthetic American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Member"), email_address: "member@example.test")
    @user.permission_grants.create!(capability: "manage_agendas")
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @agenda = create_dated_agenda!(organization: organization, meeting_body: body, meeting_type: type, starts_at: 1.week.from_now, title: "Synthetic Shared Agenda")
    @agenda.approve!(@user)
    @agenda.publish!(@user)
  end

  teardown do
    Rails.application.config.x.members_site = @original_identity
    ActionController::Base.allow_forgery_protection = @original_forgery_protection
    Capybara.app_host = @original_app_host
    WebAuthn.configuration.allowed_origins = @original_origins
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "email code returns a member to the shared agenda at phone width" do
    visit dated_agenda_path(@agenda)
    assert_current_path new_session_path
    [ 1400, 390, 320 ].each do |width|
      page.driver.browser.manage.window.resize_to(width, 1000)
      assert_selector "h1", text: "POST 165 MEMBERS"
      assert_title "Post 165 Members", exact: true
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      assert_operator page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.entry-lead')).fontSize)"), :>=, 16
      assert_selector "head link[rel='icon'][href='/favicon.svg']", visible: :all
      capture_system_screenshot("members-entry-#{width}")
    end
    page.driver.browser.manage.window.resize_to(390, 900)
    request_email
    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    fill_in "8-digit sign-in code", with: code
    capture_system_screenshot("members-code-390")
    click_button "Finish signing in"
    assert_shared_agenda
    page.refresh
    assert_shared_agenda
    assert_equal 1, @user.sessions.count
  end

  test "email link confirmation returns to the shared agenda without consuming on preview" do
    visit dated_agenda_path(@agenda)
    request_email
    token = ActionMailer::Base.deliveries.last.text_part.body.to_s[/token=([A-Za-z0-9_-]+)/, 1]
    link = @user.magic_links.order(:created_at).last
    visit magic_link_session_path(token: token)
    assert_button "Finish signing in"
    assert_nil link.reload.used_at
    assert_equal 0, @user.sessions.count
    capture_system_screenshot("members-link-confirmation-1400")
    click_button "Finish signing in"
    assert_shared_agenda
    assert link.reload.used_at
    visit dated_agenda_path(@agenda)
    assert_shared_agenda
  end

  test "a real browser passkey ceremony returns to the shared agenda" do
    page.driver.browser.execute_cdp("WebAuthn.enable")
    authenticator = page.driver.browser.execute_cdp("WebAuthn.addVirtualAuthenticator", options: {
      protocol: "ctap2", transport: "internal", hasResidentKey: true,
      hasUserVerification: true, isUserVerified: true, automaticPresenceSimulation: true
    })
    system_sign_in(@user)
    visit profile_path
    fill_in "new-passkey-nickname", with: "Synthetic test device"
    click_button "Add a passkey"
    assert_selector "input.pk-name-field[value='Synthetic test device']"
    assert_equal 1, @user.passkey_credentials.count
    credential = @user.passkey_credentials.sole
    click_button "Menu"
    click_button "Sign out"
    assert_current_path new_session_path
    assert_button "Sign in with a passkey"
    assert_equal 0, @user.sessions.count
    visit dated_agenda_path(@agenda)
    assert_current_path new_session_path
    click_button "Sign in with a passkey"
    assert_shared_agenda
    assert credential.reload.last_used_at
    assert_equal 1, @user.sessions.count
    page.refresh
    assert_shared_agenda
  ensure
    if authenticator
      page.driver.browser.execute_cdp("WebAuthn.removeVirtualAuthenticator", authenticatorId: authenticator.fetch("authenticatorId"))
    end
  end

  private

  def request_email
    fill_in "Email address", with: @user.email_address
    assert_emails 1 do
      click_button "Send my sign-in email"
      assert_current_path code_session_path
      assert_field "8-digit sign-in code"
    end
  end

  def assert_shared_agenda
    assert_current_path dated_agenda_path(@agenda)
    assert_selector "article.agenda-doc", text: "Synthetic Shared Agenda"
    assert_selector ".app-menu-btn", text: "Menu"
    assert_selector "meta[property='og:title'][content='Post 165 Members']", visible: :all
    assert_title @agenda.title
  end
end
