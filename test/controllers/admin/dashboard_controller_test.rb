require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated admin root redirects to sign in" do
    prepare_setup_complete_state

    get admin_root_path

    assert_redirected_to new_session_path
  end

  test "signed in user without manage_settings is denied" do
    prepare_setup_complete_state
    user = sign_in_member(can_manage_settings: false)

    get admin_root_path

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "signed in user with manage_settings can open admin dashboard" do
    prepare_setup_complete_state
    sign_in_member
    RosterImport.create!(
      uploaded_filename: "roster-2026.csv",
      status: "completed",
      imported_at: 2.days.ago,
      created_count: 3,
      updated_count: 4,
      unchanged_count: 5,
      problem_count: 0
    )

    get admin_root_path

    assert_response :success
    assert_select "h1", "Administration"
    assert_select "p", "Manage the roster import, accounts, permissions, and post roles."
    assert_select "a[href=?]", admin_people_path, text: "People"
    assert_select "p", /Latest successful roster import: /
    assert_select "p[role='alert']", 0
    assert_select "p", { count: 0, text: /roster-2026\.csv/ }
    assert_select "p", { count: 0, text: /Status: / }
    assert_select "p", { count: 0, text: /Created: / }
  end

  test "signed in user with manage_settings sees empty roster state when no import exists" do
    prepare_setup_complete_state
    sign_in_member

    get admin_root_path

    assert_response :success
    assert_select "h1", "Administration"
    assert_select "p", "Manage the roster import, accounts, permissions, and post roles."
    assert_select "p", "No roster has been imported yet."
    assert_select "p[role='alert']", "The roster is more than 30 days old or has not been imported yet. Upload a current National roster export."
  end

  test "signed in user with manage_settings sees stale roster warning when import is old" do
    prepare_setup_complete_state
    sign_in_member
    RosterImport.create!(
      uploaded_filename: "roster-2026.csv",
      status: "completed",
      imported_at: 31.days.ago,
      created_count: 3,
      updated_count: 4,
      unchanged_count: 5,
      problem_count: 0
    )

    get admin_root_path

    assert_response :success
    assert_select "p", /Latest successful roster import: /
    assert_select "p[role='alert']", "The roster is more than 30 days old or has not been imported yet. Upload a current National roster export."
  end

  private

  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_member(can_manage_settings: true)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings") if can_manage_settings
    sign_in_as(user)
    user
  end
end
