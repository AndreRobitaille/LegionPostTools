require "application_system_test_case"

class AdministratorPermissionsSystemTest < ApplicationSystemTestCase
  test "last administrator refusal preserves permissions and later permitted handoff works" do
    Organization.create!(name: "Synthetic administration Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Current", last_name: "Administrator")
    user = User.create!(person: person, email_address: "current-admin@example.test")
    %w[manage_settings manage_people].each { |capability| user.permission_grants.create!(capability: capability) }
    system_sign_in(user)
    original_grants = user.permission_grants.order(:id).map(&:attributes)
    original_identity = [ person.reload.attributes, user.reload.attributes ]

    [ [ 1400, 1400 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit person_path(person)
      uncheck "Manage app settings"
      click_button "Save permissions"
      assert_text "At least one enabled administrator account is required."
      assert_equal original_grants, user.permission_grants.order(:id).map(&:attributes)
      assert_equal original_identity, [ person.reload.attributes, user.reload.attributes ]
      assert_checked_field "Manage app settings"
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth"), "Permission refusal overflow at #{width}px"
      capture_system_screenshot("administrator-refusal-#{width}")
    end

    successor = User.create!(person: Person.create!(first_name: "Next", last_name: "Administrator"), email_address: "next-admin@example.test")
    successor.permission_grants.create!(capability: "manage_settings")
    visit person_path(person)
    uncheck "Manage app settings"
    click_button "Save permissions"
    assert_text "Permissions updated."
    assert_equal [ "manage_people" ], user.permission_grants.order(:capability).pluck(:capability)
    assert_equal original_identity, [ person.reload.attributes, user.reload.attributes ]
    assert_no_button "Save permissions"
    visit new_admin_roster_import_path
    assert_current_path root_path
    assert_no_selector "h1", text: "Import roster"
    assert successor.reload.can?("manage_settings")
    assert_nil successor.disabled_at

    system_sign_in(successor)
    visit new_admin_roster_import_path
    assert_selector "h1", text: "Import roster"
    assert_button "Upload and import"
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
