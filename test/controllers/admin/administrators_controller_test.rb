require "test_helper"

class Admin::AdministratorsControllerTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    @org = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_admin
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
    user
  end

  test "index lists enabled administrators and links to their person pages" do
    prepare_setup_complete_state
    admin = sign_in_admin

    get admin_administrators_path

    assert_response :success
    assert_select ".admrow .an", text: admin.person.full_name
    assert_select "a[href=?]", person_path(admin.person), text: /Manage on their page/
    assert_select "a[href=?]", admin_root_path, text: /Back to Administration/
  end

  test "index requires manage_settings" do
    prepare_setup_complete_state
    person = Person.create!(first_name: "Sam", last_name: "Roe")
    user = User.create!(person: person, email_address: "sam@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_agendas")
    sign_in_as(user)

    get admin_administrators_path

    assert_redirected_to root_path
  end
end
