# test/integration/primary_nav_test.rb
require "test_helper"

class PrimaryNavTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_admin
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
    user
  end

  def sign_in_plain_member
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    sign_in_as(user)
    user
  end

  def sign_in_agenda_manager
    person = Person.create!(first_name: "Sam", last_name: "Roe")
    user = User.create!(person: person, email_address: "sam@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_agendas")
    sign_in_as(user)
    user
  end

  test "authenticated shell renders the primary nav with core and soon tabs" do
    prepare_setup_complete_state
    sign_in_admin
    get root_path
    assert_response :success
    assert_select "nav.nav-bar a.nav-tab", text: "Dashboard"
    assert_select "nav.nav-bar a.nav-tab", text: "Settings"
    assert_select "nav.nav-bar .nav-tab--soon", text: /Meetings/
    assert_select "nav.nav-bar .nav-tab--soon", text: /Records/
    assert_select "nav.nav-bar .nav-tab--soon", text: /Tracked Items/
  end

  test "admin sees People and Admin tabs" do
    prepare_setup_complete_state
    sign_in_admin
    get root_path
    assert_select "nav.nav-bar a.nav-tab", text: "People"
    assert_select "nav.nav-bar a.nav-tab--admin[href=?]", admin_root_path, text: /Admin/
  end

  test "agenda manager sees Admin tab linking to meeting types" do
    prepare_setup_complete_state
    sign_in_agenda_manager
    get root_path
    assert_select "nav.nav-bar a.nav-tab--admin[href=?]", admin_meeting_types_path, text: /Admin/
    assert_select "nav.nav-bar a.nav-tab--admin[href=?]", admin_agenda_item_catalog_entries_path, count: 0
    assert_select "nav.nav-bar a.nav-tab--admin[href=?]", admin_root_path, count: 0
  end

  test "plain member sees People but not Admin tab" do
    prepare_setup_complete_state
    sign_in_plain_member
    get root_path
    assert_select "nav.nav-bar a.nav-tab--admin", count: 0
    assert_select "nav.nav-bar a.nav-tab", text: "People"
  end

  test "active tab reflects the current section" do
    prepare_setup_complete_state
    sign_in_admin
    get people_path
    assert_select "nav.nav-bar a.nav-tab--active", text: "People"
  end
end
