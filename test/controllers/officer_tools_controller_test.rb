require "test_helper"

class OfficerToolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Harbor Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Morgan", last_name: "Reed"), email_address: "morgan@example.com")
  end

  test "sign in and current duties are required" do
    get officer_tools_path
    assert_redirected_to new_session_path
    sign_in_as(@user)
    get officer_tools_path
    assert_redirected_to root_path
    get root_path
    assert_select ".app-menu-link[href=?]", officer_tools_path, count: 0
    assert_select ".app-menu-link[href=?]", admin_root_path, count: 0
  end

  test "current first vice finds Membership and loses the hub when the assignment ends" do
    title = @organization.position_titles.create!(name: "1st Vice Commander", display_order: 1, grants_full_membership_access: true)
    office = title.position_assignments.create!(person: @user.person, starts_on: Organization.current_local_date - 1)
    sign_in_as(@user)
    get officer_tools_path
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "a.workspace-destination[href=?]", membership_root_path, text: /Renewal follow-up/
    assert_select ".officer-workspace-context", text: /1st Vice Commander/
    assert_select ".app-menu-link[href=?]", admin_root_path, count: 0
    get admin_root_path
    assert_redirected_to officer_tools_path
    office.update!(ends_on: Organization.current_local_date - 1)
    get officer_tools_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".app-menu-link[href=?]", officer_tools_path, count: 0
    get membership_root_path
    assert_response :forbidden
  end

  test "separate administrator and officer hubs retain different destinations" do
    @user.permission_grants.create!(capability: "manage_settings")
    @user.permission_grants.create!(capability: "publish_public_content")
    sign_in_as(@user)
    get officer_tools_path
    assert_response :success
    assert_select ".app-menu-link[href=?][aria-current=page]", officer_tools_path
    assert_select ".app-menu-link[href=?]", admin_root_path
    assert_select "a.workspace-destination[href=?]", admin_meetings_path
    assert_select "a.workspace-destination[href=?]", membership_root_path
    assert_select "a.workspace-destination[href=?]", admin_website_publications_path
    assert_select "a.workspace-destination[href=?]", new_admin_roster_import_path, count: 0
    get admin_root_path
    assert_response :success
    assert_select ".app-menu-link[href=?][aria-current=page]", admin_root_path
    assert_select "a.workspace-destination[href=?]", new_admin_roster_import_path
    assert_select "a.workspace-destination[href=?]", admin_meetings_path, count: 0
    assert_select "a.workspace-destination[href=?]", membership_root_path, count: 0
    assert_select "a.workspace-destination[href=?]", admin_website_publications_path, count: 0
  end

  test "minutes approver and attestor reach shared records without internal access" do
    %w[approve_minutes attest_minutes].each do |capability|
      grant = @user.permission_grants.create!(capability:)
      sign_in_as(@user)
      get officer_tools_path
      assert_response :success
      assert_select "a.workspace-destination[href=?]", meetings_path
      assert_select "a.workspace-destination", count: 1
      get admin_meetings_path
      assert_redirected_to root_path
      grant.destroy!
    end
  end
end
