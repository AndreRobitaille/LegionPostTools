require "application_system_test_case"

class LocalAccountProvenanceSystemTest < ApplicationSystemTestCase
  test "real setup and local account controls keep truthful source panels beside imported records" do
    visit new_setup_path
    fill_in "Post name", with: "Synthetic source review Post"
    fill_in "First name", with: "First"
    fill_in "Last name", with: "Administrator"
    fill_in "Email address", with: "first-admin@example.test"
    click_button "Create your post"
    assert_selector "h1", text: "Post meetings"
    admin = User.find_by!(email_address: "first-admin@example.test")
    original_admin = [ admin.person.attributes, admin.attributes, admin.permission_grants.order(:id).map(&:attributes) ]
    assert_not admin.login_access_override?
    assert_nil admin.person.member_number

    [ 1400, 390 ].each do |width|
      resize_for(width)
      visit person_path(admin.person)
      assert_local_panel
      capture_system_screenshot("first-local-account-#{width}")
    end
    assert_equal original_admin, [ admin.person.reload.attributes, admin.reload.attributes, admin.permission_grants.order(:id).map(&:attributes) ]

    local = Person.create!(first_name: "Local", last_name: "Member")
    original_person = local.attributes
    visit person_path(local)
    fill_in "Login email", with: "local-member@example.test"
    click_button "Create login account"
    assert_text "This local account is managed manually because it has no National roster record."
    local_user = local.reload.user
    assert_equal "local-member@example.test", local_user.email_address
    assert_nil local_user.email_verified_at
    assert local_user.login_access_override?
    assert_empty local_user.permission_grants
    [ 1400, 390 ].each do |width|
      resize_for(width)
      visit person_path(local)
      assert_local_panel
      capture_system_screenshot("created-local-account-#{width}")
    end

    click_button "Disable sign-in"
    assert_text "Sign-in is off."
    assert_equal "manual", local_user.reload.disabled_reason
    assert local_user.disabled_at
    fill_in "Login email", with: "local-member@example.test"
    click_button "Save email and enable sign-in"
    assert_text "Sign-in is on."
    assert_nil local_user.reload.disabled_at
    assert_equal "local-member@example.test", local_user.email_address
    assert_equal original_person, local.reload.attributes
    check "View internal meeting records"
    click_button "Save permissions"
    assert_text "Permissions updated."
    assert_equal [ "view_internal_records" ], local_user.permission_grants.pluck(:capability)

    imported = Person.create!(first_name: "National", last_name: "Member", member_number: "M115",
      roster_name: "Member, National", roster_member_status: "Active", roster_email_address: "national@example.test",
      roster_imported_at: Time.utc(2026, 10, 10, 18), roster_undeliverable: true)
    imported_user = User.create!(person: imported, email_address: "national@example.test")
    original_imported = [ imported.attributes, imported_user.attributes ]
    [ 1400, 390 ].each do |width|
      resize_for(width)
      visit person_path(imported)
      assert_selector ".card-head-prov", text: "National roster · imported 10 OCT 2026"
      assert_selector ".kv", text: /Mail deliverable\s+No/i
      assert_text "These fields come from the National roster"
      assert_text "Sign-in follows the National roster."
      assert_no_text "Local Post record"
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      capture_system_screenshot("imported-account-#{width}")
    end
    assert_equal original_imported, [ imported.reload.attributes, imported_user.reload.attributes ]
    assert_equal original_admin, [ admin.person.reload.attributes, admin.reload.attributes, admin.permission_grants.order(:id).map(&:attributes) ]

    click_button "Menu"
    click_button "Sign out"
    visit profile_path
    assert_current_path new_session_path
    assert_no_selector "h1", text: "Your profile"
    system_sign_in(local_user)
    visit profile_path
    assert_selector ".profile-lead .page-sub", text: "Local Member"
    assert_no_text "first-admin@example.test"
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def resize_for(width)
    page.current_window.resize_to(width, width == 1400 ? 1400 : 844)
  end

  def assert_local_panel
    assert_selector ".card-head-prov", text: "Local Post record"
    assert_text "No National roster record is linked to this person."
    assert_text "Sign-in is managed locally."
    assert_no_text "Sign-in follows the National roster."
    assert_no_selector ".k", text: "Mail deliverable"
    assert_no_button "Use automatic roster access"
    assert_operator find(".panel-lead").evaluate_script("parseFloat(getComputedStyle(this).fontSize)"), :>=, 16
    assert_operator find(".acct-mode").evaluate_script("parseFloat(getComputedStyle(this).fontSize)"), :>=, 16
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end
end
