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

  test "authenticated shell links every available destination and omits unavailable records" do
    prepare_setup_complete_state
    sign_in_admin
    get root_path
    assert_response :success
    assert_select "nav.nav-bar a.nav-tab", text: "Dashboard"
    assert_select "nav.nav-bar a.nav-tab[href=?]", dated_agendas_path, text: "Meetings"
    assert_select "nav.nav-bar a.nav-tab[href=?]", tracked_items_path, text: "Tracked Items"
    assert_select "nav.nav-bar", text: /Records/, count: 0
    assert_select "nav.nav-bar .nav-tab--soon", count: 0
    # Profile and Sign out moved off the tab strip into the account menu.
    assert_select "nav.nav-bar a.nav-tab", text: "Settings", count: 0
    assert_select ".app-menu-panel a.app-menu-link[href=?]", profile_path, text: "Your profile"
  end

  test "account menu names the signed-in member and their office" do
    prepare_setup_complete_state
    sign_in_admin
    get root_path

    assert_response :success
    assert_select ".app-menu-btn[aria-expanded='false'][aria-controls='app-menu-panel']", text: /Menu/
    assert_select ".app-menu-btn[aria-haspopup]", count: 0
    assert_select ".app-menu-id .app-menu-id-text strong", text: "Jane Doe"
    # The officer label left the top bar; only the menu carries it now.
    assert_select ".app-user .app-user-name", text: "Jane Doe"
    assert_select ".app-user", text: /Commander/, count: 0
  end

  test "account menu carries the same destinations as the tab strip" do
    prepare_setup_complete_state
    sign_in_admin
    get root_path

    assert_response :success
    assert_select ".app-menu-nav a.app-menu-link[href=?]", dated_agendas_path, text: "Meetings"
    assert_select ".app-menu-nav a.app-menu-link[href=?]", tracked_items_path, text: "Tracked Items"
    assert_select ".app-menu-nav a.app-menu-link[href=?]", admin_root_path, text: "Admin"
  end

  test "account menu omits Admin for a plain member" do
    prepare_setup_complete_state
    sign_in_plain_member
    get root_path

    assert_select ".app-menu-nav a.app-menu-link[href=?]", admin_root_path, count: 0
    assert_select ".app-menu-nav a.app-menu-link[href=?]", people_path, text: "People"
  end

  test "menu marks the current destination" do
    prepare_setup_complete_state
    sign_in_admin

    get people_path

    assert_select ".app-menu-nav a.app-menu-link--active[aria-current='page'][href=?]", people_path
  end

  test "sign out posts from inside the menu" do
    prepare_setup_complete_state
    sign_in_admin
    get root_path

    assert_select ".app-menu-actions form[action=?][method='post']", session_path do
      assert_select "input[name='_method'][value='delete']", visible: false
      assert_select "button.app-menu-link--signout", text: "Sign out"
    end
  end

  test "admin sees People and Admin tabs" do
    prepare_setup_complete_state
    sign_in_admin
    get root_path
    assert_select "nav.nav-bar a.nav-tab", text: "People"
    assert_select "nav.nav-bar a.nav-tab--admin", text: /Admin/
  end

  test "agenda manager sees Admin tab linking to the hub" do
    prepare_setup_complete_state
    sign_in_agenda_manager
    get root_path
    assert_select "nav.nav-bar a.nav-tab--admin[href=?]", admin_root_path, text: /Admin/
    assert_select "nav.nav-bar a.nav-tab--admin[href=?]", admin_agenda_item_catalog_entries_path, count: 0
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

  test "tracked items tab is active within tracked item pages" do
    prepare_setup_complete_state
    sign_in_admin

    get tracked_items_path

    assert_select "nav.nav-bar a.nav-tab--active", text: "Tracked Items"
  end

  test "meetings tab is active and marked current on member agenda pages" do
    prepare_setup_complete_state
    sign_in_plain_member

    get dated_agendas_path

    assert_response :success
    assert_select "nav.nav-bar a.nav-tab--active[aria-current='page'][href=?]", dated_agendas_path, text: "Meetings"
  end
end
