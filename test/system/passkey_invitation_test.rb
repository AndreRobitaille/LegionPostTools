require "application_system_test_case"

class PasskeyInvitationSystemTest < ApplicationSystemTestCase
  setup do
    Organization.create!(name: "Synthetic American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Member"), email_address: "invitation-member@example.test")
    other = User.create!(person: Person.create!(first_name: "Other", last_name: "Member"), email_address: "other-invitation@example.test")
    other.permission_grants.create!(capability: "manage_minutes")
    PasskeyCredential.create!(user: other, external_id: "other-invitation-credential", public_key: "synthetic-public-key", sign_count: 0)
    Session.create!(user: other, last_seen_at: Time.current)
  end

  test "Not now preserves account access and a fresh sign-in offers the optional invitation again" do
    freeze_time
    system_sign_in(@user)
    assert_selector ".pk-card--sidebar", text: "Sign in faster with a passkey"
    original = identity_records
    original_sessions = Session.order(:id).map(&:attributes)
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      assert_no_horizontal_overflow
      page.execute_script("document.querySelector('.pk-card--sidebar').scrollIntoView({block: 'start'})")
      capture_system_screenshot("passkey-invitation-visible-#{width}")
    end

    click_button "Not now"
    assert_no_selector ".pk-card--sidebar"
    assert_equal original, identity_records
    assert_equal original_sessions, Session.order(:id).map(&:attributes)
    assert_current_path root_path
    find(".app-menu-btn").click
    click_link "Your profile"
    assert_selector ".profile-lead .page-sub", text: @user.person.full_name
    assert_no_text "other-invitation@example.test"
    assert_equal original, identity_records
    visit root_path
    assert_no_selector ".pk-card--sidebar"
    assert_equal original_sessions, Session.order(:id).map(&:attributes)
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      assert_no_horizontal_overflow
      capture_system_screenshot("passkey-invitation-dismissed-#{width}")
    end

    current_session = @user.sessions.sole
    other_sessions = original_sessions.reject { |record| record.fetch("user_id") == @user.id }
    find(".app-menu-btn").click
    click_button "Sign out"
    assert_current_path new_session_path
    assert_not Session.exists?(current_session.id)
    assert_equal other_sessions, Session.where.not(user: @user).order(:id).map(&:attributes)
    visit profile_path
    assert_current_path new_session_path
    assert_no_selector ".app-menu-btn"
    assert_equal original, identity_records

    system_sign_in(@user)
    assert_selector ".pk-card--sidebar", text: "Sign in faster with a passkey"
    assert_equal original, identity_records
    assert_equal 1, @user.sessions.count
    assert_not_equal current_session.id, @user.sessions.sole.id
    assert_equal other_sessions, Session.where.not(user: @user).order(:id).map(&:attributes)
    assert_no_horizontal_overflow
    page.execute_script("document.querySelector('.pk-card--sidebar').scrollIntoView({block: 'start'})")
    capture_system_screenshot("passkey-invitation-fresh-sign-in-390")
  end

  private

  def identity_records
    [ Person, User, PermissionGrant, PasskeyCredential ].map { |model| model.order(:id).map(&:attributes) }
  end

  def assert_no_horizontal_overflow
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("window.innerWidth")
  end
end
