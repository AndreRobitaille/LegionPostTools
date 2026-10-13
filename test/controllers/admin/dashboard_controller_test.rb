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

  test "administrator sees settings separately from officer duties" do
    prepare_setup_complete_state
    admin = sign_in_member(can_manage_settings: true, can_manage_agendas: true)
    admin.permission_grants.create!(capability: "publish_public_content")

    get admin_root_path

    assert_response :success
    assert_select "h1", "Administration"
    assert_select ".app-menu-link[aria-current=page][href=?]", admin_root_path, text: "Administration"
    assert_select ".app-menu-link[href=?]", officer_tools_path, text: "Officer tools"
    assert_select ".officer-workspace-context", count: 0
    assert_equal [ "People and roster", "Access", "Public website", "Operations" ],
      css_select(".workspace-group h2").map(&:text)
    assert_workspace_destinations new_admin_roster_import_path, admin_roster_imports_path,
      new_admin_loops_roster_sync_path, admin_position_titles_path,
      admin_website_access_tokens_path, admin_jobs_path, admin_administrators_path, admin_agent_access_tokens_path
    [ admin_meetings_path, admin_endeavors_path, admin_agenda_item_catalog_entries_path,
      admin_meeting_types_path, admin_website_publications_path ].each do |path|
      assert_select "a.workspace-destination[href=?]", path, count: 0
    end
    assert_select "a[href=?]", new_admin_roster_import_path, text: /Import roster/
    assert_select "a[href=?]", new_admin_loops_roster_sync_path, text: /Sync email audience/
    assert_select "a[href=?]", admin_roster_imports_path, text: /Import history/
    assert_select "a[href=?]", admin_jobs_path, text: /Background Jobs/
    assert_select "a[href=?]", admin_position_titles_path, text: /Post positions/
    assert_select "a[href=?]", admin_administrators_path, text: /Administrators/
  end

  test "agenda-only manager reaches the hub and sees only authorized destinations" do
    prepare_setup_complete_state
    officer = sign_in_member(can_manage_settings: false)
    adjutant = @org.position_titles.create!(name: "Adjutant", display_order: 1, active: true)
    adjutant.position_capability_grants.create!(capability: "manage_agendas")
    PositionAssignment.create!(person: officer.person, position_title: adjutant, starts_on: Date.current)

    get officer_tools_path

    assert_response :success
    assert_select "h1", "Officer tools"
    assert_select ".app-menu-link[aria-current=page][href=?]", officer_tools_path, text: "Officer tools"
    assert_select ".officer-workspace-context", text: /Post duties.*Adjutant.*current roles and permissions/m
    assert_select ".workspace-group h2", text: "Meeting work"
    assert_select "a[href=?]", admin_agenda_item_catalog_entries_path, text: /Agenda catalog/
    assert_select "a[href=?]", admin_meeting_types_path, text: /Meeting types/
    assert_select "a[href=?]", admin_meetings_path, text: /Meetings/
    assert_workspace_destinations admin_meetings_path, admin_endeavors_path,
      admin_agenda_item_catalog_entries_path, admin_meeting_types_path, admin_jobs_path
    assert_select ".workspace-group h2", text: "People and roster", count: 0
    assert_select ".workspace-group h2", text: "Access", count: 0
    assert_select "a[href=?]", admin_position_titles_path, count: 0
    assert_select "a[href=?]", new_admin_roster_import_path, count: 0
  end

  test "scoped officer pages return to officer tools" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: false, can_manage_agendas: true)

    get admin_meeting_types_path
    assert_select "a.back[href=?]", officer_tools_path, text: /Officer tools/

    get admin_agenda_item_catalog_entries_path
    assert_select "a.back[href=?]", officer_tools_path, text: /Officer tools/
  end

  test "minutes manager reaches the hub and sees meeting records and background jobs" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: false, can_manage_minutes: true)

    get officer_tools_path

    assert_response :success
    assert_select "a[href=?]", admin_meetings_path, text: /Meetings/
    assert_select "a[href=?]", admin_jobs_path, text: /Background Jobs/
    assert_workspace_destinations admin_meetings_path, admin_jobs_path
    assert_select "a.workspace-destination[href=?]", admin_meetings_path, text: /Open meetings and continue their minutes/
    assert_select "a[href=?]", admin_agenda_item_catalog_entries_path, count: 0
    assert_select "a[href=?]", admin_meeting_types_path, count: 0
    assert_select "a[href=?]", new_admin_roster_import_path, count: 0
  end

  test "current roster remains visible without an attention area" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)
    RosterImport.create!(uploaded_filename: "roster.csv", status: "completed", imported_at: 2.days.ago,
                         created_count: 1, updated_count: 0, unchanged_count: 0, problem_count: 0)

    get admin_root_path

    assert_response :success
    assert_select ".workspace-roster-status--current", text: "Current"
    assert_select ".workspace-destination", text: /Import roster.*Last imported/m
    assert_select ".workspace-attention", count: 0
  end

  test "overdue roster has one attention area beside its import action" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)
    RosterImport.create!(uploaded_filename: "roster.csv", status: "completed", imported_at: 31.days.ago,
                         created_count: 1, updated_count: 0, unchanged_count: 0, problem_count: 0)

    get admin_root_path

    assert_response :success
    assert_select ".workspace-roster-status--due", text: "Import due"
    assert_select ".workspace-attention", count: 1 do
      assert_select "h3", text: "Roster import is due"
      assert_select "a[href=?]", new_admin_roster_import_path, text: "Import roster"
    end
  end

  test "missing roster explains the first import and keeps its actions available" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)

    get admin_root_path

    assert_response :success
    assert_select ".workspace-roster-status--due", text: "Not imported"
    assert_select ".workspace-attention h3", text: "Import your first roster"
    assert_select "a[href=?]", admin_roster_imports_path
    assert_select "a[href=?]", new_admin_loops_roster_sync_path
  end

  test "publisher without settings gets only publishing and no empty groups" do
    prepare_setup_complete_state
    user = sign_in_member(can_manage_settings: false)
    user.permission_grants.create!(capability: "publish_public_content")

    get officer_tools_path
    assert_response :success
    assert_workspace_destinations admin_website_publications_path
    assert_equal [ "Public website" ], css_select(".workspace-group h2").map(&:text)
    assert_select ".workspace-attention", count: 0

    get admin_website_publications_path
    assert_response :success
    get admin_website_access_tokens_path
    assert_redirected_to root_path
    get officer_tools_path
    assert_workspace_destinations admin_website_publications_path
  end

  test "settings access does not imply public publishing authority" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)

    get admin_root_path
    assert_select "a.workspace-destination[href=?]", admin_website_access_tokens_path
    assert_select "a[href=?]", admin_website_publications_path, count: 0
    get admin_website_publications_path
    assert_redirected_to root_path
  end

  test "record viewer sees Meetings and cannot reach Background Jobs" do
    prepare_setup_complete_state
    user = sign_in_member(can_manage_settings: false)
    grant = user.permission_grants.create!(capability: "view_internal_records")

    get officer_tools_path
    assert_response :success
    assert_workspace_destinations admin_meetings_path
    assert_select "a.workspace-destination[href=?]", admin_meetings_path, text: /Read internal meeting records/
    assert_equal [ "Meeting work" ], css_select(".workspace-group h2").map(&:text)
    get admin_meetings_path
    assert_response :success
    get admin_jobs_path
    assert_redirected_to root_path

    grant.destroy!
    get officer_tools_path
    assert_redirected_to root_path
    get admin_meetings_path
    assert_redirected_to root_path
  end

  test "opening the hub repeatedly starts no background or paid work" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true, can_manage_agendas: true, can_manage_minutes: true)

    assert_no_difference [ "MinutesDraftRun.count", "EndeavorHistoryRun.count", "RosterImport.count" ] do
      assert_no_enqueued_jobs do
        2.times do
          get admin_root_path
          assert_response :success
        end
      end
    end
  end

  test "approval-only authority reaches shared meeting actions" do
    prepare_setup_complete_state
    user = sign_in_member(can_manage_settings: false)
    user.permission_grants.create!(capability: "record_minutes_approval")

    get officer_tools_path
    assert_response :success
    assert_workspace_destinations meetings_path
    assert_select "a.workspace-destination", text: /View shared meeting records and the actions available to you/
  end

  private

  def assert_workspace_destinations(*paths)
    assert_equal paths.sort, css_select("a.workspace-destination").map { |link| link["href"] }.sort
  end

  def prepare_setup_complete_state
    @org = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_member(can_manage_settings: true, can_manage_agendas: false, can_manage_minutes: false)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings") if can_manage_settings
    PermissionGrant.create!(user: user, capability: "manage_agendas") if can_manage_agendas
    PermissionGrant.create!(user: user, capability: "manage_minutes") if can_manage_minutes
    sign_in_as(user)
    user
  end
end
