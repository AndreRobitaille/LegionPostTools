require "application_system_test_case"

# Browser coverage for the header's account menu: the open/close behaviour a
# request test can't reach, and the phone-width promise that the destinations
# stay reachable once the tab strip stands down.
class AccountMenuSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    page.current_window.resize_to(1400, 1400)
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    title = PositionTitle.create!(organization: @organization, name: "Commander", display_order: 1)
    PositionAssignment.create!(person: person, position_title: title, starts_on: Date.current - 1.month)
    @user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @user, capability: "manage_agendas")
    system_sign_in(@user)
  end

  test "the menu starts closed and opens on click" do
    visit root_path

    assert_selector ".app-menu-btn[aria-expanded='false']", text: "Menu"
    assert_no_selector ".app-menu-panel a", text: "Your profile"

    click_button "Menu"

    assert_selector ".app-menu-btn[aria-expanded='true']"
    assert_selector ".app-menu-panel", text: "Jane Doe"
    assert_selector ".app-menu-id-role", text: /commander/i
    assert_link "Your profile"
  end

  test "escape closes the menu and returns focus to the button" do
    visit root_path
    click_button "Menu"
    assert_selector ".app-menu-btn[aria-expanded='true']"

    # Walk into the menu the way a keyboard user would, then back out.
    find(".app-menu-btn").send_keys(:arrow_down)
    first(".app-menu-panel a").send_keys(:escape)

    assert_selector ".app-menu-btn[aria-expanded='false']"
    assert_match(/Menu/, page.evaluate_script("document.activeElement.textContent"))
  end

  test "clicking outside closes the menu" do
    visit root_path
    click_button "Menu"
    assert_selector ".app-menu-btn[aria-expanded='true']"

    find("h1", match: :first).click

    assert_selector ".app-menu-btn[aria-expanded='false']"
  end

  test "the menu reaches the profile page" do
    visit root_path
    click_button "Menu"
    click_link "Your profile"

    assert_selector "h1", text: "Your profile"
    assert_selector ".sec-head-label", text: /how you sign in/i
  end

  test "signing out from the menu ends the session" do
    visit root_path
    sign_out_and_verify_access_ended
  end

  test "signing out with a pending minutes approval ends the session" do
    begin_minutes_approval
    sign_out_and_verify_access_ended

    assert_nil @confirmation.reload.session_id
    assert_predicate @minutes.reload, :draft?
  end

  test "signing out after completing a minutes approval ends the session and preserves the approval" do
    begin_minutes_approval
    perform_enqueued_jobs do
      click_button "Email me a code and link"
      assert_field "8-digit confirmation code"
    end
    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    assert code
    fill_in "8-digit confirmation code", with: code
    click_button "Confirm and complete"
    assert_text "Draft sent to the Adjutant for review."
    revision = @minutes.reload.current_revision

    sign_out_and_verify_access_ended

    assert_predicate @minutes.reload, :approved?
    assert_equal revision, @minutes.current_revision
    assert_nil @confirmation.reload.session_id
    assert @confirmation.consumed_at
  end

  test "at phone width the tab strip stands down and the menu carries the destinations" do
    page.driver.browser.manage.window.resize_to(390, 900)
    visit root_path

    assert_no_selector "nav.nav-bar", visible: true
    click_button "Menu"

    assert_link "Meetings"
    assert_link "Endeavors"
    assert_link "People"
    assert_link "Officer tools"
    assert_link "Your profile"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  private

  def begin_minutes_approval
    %w[manage_minutes approve_minutes].each { |capability| PermissionGrant.create!(user: @user, capability:) }
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: 1.day.ago, title: "Test membership meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting:)
    visit new_admin_meeting_minutes_approval_path(meeting)
    click_button "Send to Adjutant"
    assert_selector "h1", text: "Confirm and complete"
    @confirmation = @user.official_action_confirmations.sole
  end

  def sign_out_and_verify_access_ended
    click_button "Menu"
    click_button "Sign out"
    assert_current_path new_session_path
    assert_selector ".entry-card-title", text: /sign in/i

    visit profile_path
    assert_current_path new_session_path
    assert_no_selector ".app-menu-btn"
  end
end
