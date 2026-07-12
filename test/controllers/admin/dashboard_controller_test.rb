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

  test "landing shows roster, positions, and administrators panels" do
    prepare_setup_complete_state
    admin = sign_in_admin
    RosterImport.create!(status: "completed", imported_at: 1.hour.ago, uploaded_filename: "latest.csv")
    PositionTitle.create!(organization: @org, name: "Commander", display_order: 1, active: true)

    get admin_root_path

    assert_response :success
    assert_select ".card-head-label", text: /Roster/
    assert_select ".card-head-label", text: /Post Positions/
    assert_select ".card-head-label", text: /Administrators/
    assert_select "body", text: /Commander/
    assert_select "body", text: /#{admin.person.full_name}/
  end

  test "roster panel shows freshness banner and recent import history" do
    prepare_setup_complete_state
    sign_in_admin
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
    assert_select ".fresh:not(.stale) .txt", text: /Roster is current\./
    assert_select ".imp", text: /roster-2026\.csv/
    assert_select "a[href=?]", admin_roster_imports_path, text: /View all imports/
  end

  test "recent imports render pending and discarded statuses without treating them as failures" do
    prepare_setup_complete_state
    sign_in_admin
    pending = RosterImport.new(status: "pending_confirmation", imported_at: 1.hour.ago, uploaded_filename: "pending.csv", removed_count: 11, problem_count: 0)
    pending.pending_csv.attach(io: StringIO.new("x"), filename: "pending.csv", content_type: "text/csv")
    pending.save!
    RosterImport.create!(status: "discarded", imported_at: 2.hours.ago, uploaded_filename: "discarded.csv")

    get admin_root_path

    assert_response :success
    assert_select ".imp .status.warn", text: /Needs confirmation/
    assert_select ".imp .status.muted", text: /Discarded/
  end

  test "recent imports tolerate an older failed import whose problems are plain strings" do
    prepare_setup_complete_state
    sign_in_admin
    legacy = RosterImport.new(status: "failed", imported_at: 1.hour.ago, uploaded_filename: "legacy.csv", problem_count: 1)
    legacy.summary = { "problems" => [ "Illegal quoting in line 1." ] }
    legacy.save!(validate: false)

    get admin_root_path

    assert_response :success
    assert_select ".imp .l2", text: /Illegal quoting in line 1\./
  end

  test "roster panel shows stale warning when no import exists" do
    prepare_setup_complete_state
    sign_in_admin

    get admin_root_path

    assert_response :success
    assert_select ".fresh.stale .txt", text: /No roster has been imported yet\./
    assert_select "a[href=?]", new_admin_roster_import_path, text: "Import roster"
  end

  test "roster panel shows stale warning when import is old" do
    prepare_setup_complete_state
    sign_in_admin
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
    assert_select ".fresh.stale .txt", text: /Roster import is due\./
  end

  private

  def prepare_setup_complete_state
    @org = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_member(can_manage_settings: true)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings") if can_manage_settings
    sign_in_as(user)
    user
  end

  def sign_in_admin
    sign_in_member(can_manage_settings: true)
  end
end
