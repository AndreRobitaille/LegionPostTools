require "test_helper"

class Admin::RosterImportsControllerTest < ActionDispatch::IntegrationTest
  test "new requires admin access and shows upload form" do
    prepare_setup_complete_state
    sign_in_member
    RosterImport.create!(
      uploaded_filename: "roster-2026.csv",
      status: "completed",
      imported_at: 31.days.ago,
      created_count: 1,
      updated_count: 0,
      unchanged_count: 0,
      problem_count: 0
    )

    get new_admin_roster_import_path

    assert_response :success
    assert_select "h1", "Upload National roster"
    assert_select "p", /Latest successful roster import: /
    assert_select "p[role='alert']", "The roster is more than 30 days old or has not been imported yet. Upload a current National roster export."
    assert_select "form[action=?][method=?]", admin_roster_imports_path, "post"
  end

  test "blank upload redirects back with alert" do
    prepare_setup_complete_state
    sign_in_member

    post admin_roster_imports_path, params: { roster_import: {} }

    assert_redirected_to new_admin_roster_import_path
    assert_equal "Choose a roster CSV file to upload.", flash[:alert]
  end

  test "non-upload file param redirects back with alert" do
    prepare_setup_complete_state
    sign_in_member

    post admin_roster_imports_path, params: { roster_import: { file: "not-a-file" } }

    assert_redirected_to new_admin_roster_import_path
    assert_equal "Choose a roster CSV file to upload.", flash[:alert]
  end

  test "malformed roster_import param redirects back with alert" do
    prepare_setup_complete_state
    sign_in_member

    post admin_roster_imports_path, params: { roster_import: "not-a-hash" }

    assert_redirected_to new_admin_roster_import_path
    assert_equal "Choose a roster CSV file to upload.", flash[:alert]
  end

  test "successful upload creates people and shows import summary" do
    prepare_setup_complete_state
    sign_in_member

    assert_difference -> { Person.count }, 2 do
      post admin_roster_imports_path, params: {
        roster_import: {
          file: fixture_file_upload("test/fixtures/files/roster_valid.csv", "text/csv")
        }
      }
    end

    roster_import = RosterImport.order(:id).last
    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "Roster import completed.", flash[:notice]

    get admin_roster_import_path(roster_import)

    assert_response :success
    assert_select "h1", "Roster import result"
    assert_select "p", /Uploaded filename: roster_valid\.csv/
    assert_select "p", /Status: completed/
  end

  test "upload with a missing member id row completes with a problem shown, no person created" do
    prepare_setup_complete_state
    sign_in_member

    assert_no_difference -> { Person.count } do
      post admin_roster_imports_path, params: {
        roster_import: {
          file: fixture_file_upload("test/fixtures/files/roster_missing_member_id.csv", "text/csv")
        }
      }
    end

    roster_import = RosterImport.order(:id).last
    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "Roster import completed.", flash[:notice]

    get admin_roster_import_path(roster_import)

    assert_response :success
    assert_select "p", /Status: completed/
    assert_select "li", /Member ID/
  end

  private

  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_member
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
  end
end
