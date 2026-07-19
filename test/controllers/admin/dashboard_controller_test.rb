require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated admin root redirects to sign in" do
    prepare_setup_complete_state
    get admin_root_path
    assert_redirected_to new_session_path
  end

  test "member with no admin capability is denied" do
    prepare_setup_complete_state
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    sign_in_as(user)

    get admin_root_path

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "full admin sees all six tiles and their links" do
    prepare_setup_complete_state
    admin = sign_in_member(can_manage_settings: true, can_manage_agendas: true)

    get admin_root_path

    assert_response :success
    assert_select ".hub-sec-h", text: "Meetings & Roster"
    assert_select ".hub-sec-h", text: "Officers & Elections"
    assert_select ".hub-sec-h", text: "Setup & Administration"
    assert_select ".tile .tile-t", text: "Roster"
    assert_select "a[href=?]", new_admin_roster_import_path, text: /Import roster/
    assert_select "a[href=?]", admin_roster_imports_path, text: /View imports/
    assert_select "a[href=?]", admin_agenda_item_catalog_entries_path, text: /Open catalog/
    assert_select "a[href=?]", admin_meeting_types_path, text: /Manage meeting types/
    assert_select "a[href=?]", admin_dated_agendas_path, text: /Manage dated agendas/
    assert_select "a[href=?]", admin_position_titles_path, text: /Manage positions/
    assert_select "a[href=?]", admin_administrators_path, text: /View administrators/
  end

  test "agenda-only manager reaches the hub and sees the agenda tiles" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: false, can_manage_agendas: true)

    get admin_root_path

    assert_response :success
    assert_select ".hub-sec-h", text: "Meetings & Roster"
    assert_select "a[href=?]", admin_agenda_item_catalog_entries_path, text: /Open catalog/
    assert_select "a[href=?]", admin_meeting_types_path, text: /Manage meeting types/
    assert_select "a[href=?]", admin_dated_agendas_path, text: /Manage dated agendas/
    assert_select ".hub-sec-h", text: "Officers & Elections", count: 0
    assert_select ".hub-sec-h", text: "Setup & Administration", count: 0
    assert_select "a[href=?]", admin_position_titles_path, count: 0
    assert_select "a[href=?]", new_admin_roster_import_path, count: 0
  end

  test "roster tile reads current when a recent import exists" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)
    RosterImport.create!(uploaded_filename: "roster.csv", status: "completed", imported_at: 2.days.ago,
                         created_count: 1, updated_count: 0, unchanged_count: 0, problem_count: 0)

    get admin_root_path

    assert_response :success
    assert_select ".tile .tile-status.ok", text: /Current/
    assert_select ".tile--due", count: 0
  end

  test "roster tile turns due and flags an overdue import" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)
    RosterImport.create!(uploaded_filename: "roster.csv", status: "completed", imported_at: 31.days.ago,
                         created_count: 1, updated_count: 0, unchanged_count: 0, problem_count: 0)

    get admin_root_path

    assert_response :success
    assert_select ".tile.tile--due .tile-status", text: /Import due/
  end

  test "roster tile flags when no roster has been imported" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)

    get admin_root_path

    assert_response :success
    assert_select ".tile.tile--due .tile-status", text: /Not imported/
  end

  private

  def prepare_setup_complete_state
    @org = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_member(can_manage_settings: true, can_manage_agendas: false)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings") if can_manage_settings
    PermissionGrant.create!(user: user, capability: "manage_agendas") if can_manage_agendas
    sign_in_as(user)
    user
  end
end
