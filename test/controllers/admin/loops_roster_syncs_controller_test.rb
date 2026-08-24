require "test_helper"

class Admin::LoopsRosterSyncsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @admin = create_user("Admin", manage_settings: true)
    @member = create_user("Member", manage_settings: false)
    @roster_import = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "national.csv")
    Person.create!(
      first_name: "Current", last_name: "Member", member_number: "M200",
      roster_member_status: "active", roster_email_address: "current@example.com"
    )
  end

  test "preview requires settings access" do
    sign_in_as(@member)

    get new_admin_loops_roster_sync_path

    assert_redirected_to root_path
  end

  test "preview explains selection and opt-out safety" do
    sign_in_as(@admin)
    with_loops_api_key do
      get new_admin_loops_roster_sync_path
    end

    assert_response :success
    assert_select "h1", "Sync roster to Loops"
    assert_select ".stat-tile--created .stat-n", "1"
    assert_select "body", text: /An existing Loops contact who opted out stays opted out/
    assert_select "form[action=?]", admin_loops_roster_syncs_path
  end

  test "preview warns when the source roster is stale" do
    @roster_import.update!(imported_at: 31.days.ago)
    sign_in_as(@admin)

    with_loops_api_key do
      get new_admin_loops_roster_sync_path
    end

    assert_response :success
    assert_select "p[role='alert']", text: /roster is more than 30 days old/
  end

  test "create records and enqueues a roster sync" do
    sign_in_as(@admin)

    with_loops_api_key do
      assert_enqueued_with(job: LoopsRosterSyncJob) do
        post admin_loops_roster_syncs_path
      end
    end

    roster_sync = LoopsRosterSync.last
    assert_redirected_to admin_loops_roster_sync_path(roster_sync)
    assert_equal @roster_import, roster_sync.roster_import
    assert_equal @admin, roster_sync.requested_by
    assert_equal 1, roster_sync.eligible_count
  end

  test "create reports missing Loops configuration" do
    sign_in_as(@admin)
    original = ENV.delete("LOOPS_API_KEY")

    post admin_loops_roster_syncs_path

    assert_redirected_to new_admin_loops_roster_sync_path
    assert_equal "Loops is not configured for this installation.", flash[:alert]
  ensure
    ENV["LOOPS_API_KEY"] = original if original
  end

  test "create sends an administrator to an existing active sync" do
    sign_in_as(@admin)
    active = LoopsRosterSync.create!(roster_import: @roster_import, requested_by: @admin, eligible_count: 1)

    with_loops_api_key do
      assert_no_enqueued_jobs do
        post admin_loops_roster_syncs_path
      end
    end

    assert_redirected_to admin_loops_roster_sync_path(active)
    assert_equal "A Loops roster sync is already in progress.", flash[:alert]
  end

  test "show renders partial failures and safety note" do
    sign_in_as(@admin)
    roster_sync = LoopsRosterSync.create!(
      roster_import: @roster_import, requested_by: @admin, status: "completed",
      eligible_count: 1, failed_count: 1, finished_at: Time.current,
      failures: [ { name: "Current Member", member_number: "M200", email: "current@example.com", message: "Rejected" } ]
    )

    get admin_loops_roster_sync_path(roster_sync)

    assert_response :success
    assert_select "h1", "Roster sync finished with problems"
    assert_select ".item", text: /Current Member/
    assert_select "body", text: /Existing opt-outs remain unchanged/
  end

  private

  def create_user(label, manage_settings:)
    person = Person.create!(first_name: label, last_name: "Officer")
    user = User.create!(person: person, email_address: "#{label.downcase}@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings") if manage_settings
    user
  end

  def with_loops_api_key
    original = ENV["LOOPS_API_KEY"]
    ENV["LOOPS_API_KEY"] = "test-key"
    yield
  ensure
    original ? ENV["LOOPS_API_KEY"] = original : ENV.delete("LOOPS_API_KEY")
  end
end
