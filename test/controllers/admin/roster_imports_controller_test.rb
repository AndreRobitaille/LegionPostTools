require "test_helper"

class Admin::RosterImportsControllerTest < ActionDispatch::IntegrationTest
  test "new requires admin access and shows upload form" do
    prepare_setup_complete_state
    sign_in_admin
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
    assert_select "h1", "Import roster"
    assert_select "p", /Latest successful roster import: /
    assert_select "p[role='alert']", "The roster is more than 30 days old or has not been imported yet. Upload a current National roster export."
    assert_select "form[action=?][method=?]", admin_roster_imports_path, "post"
  end

  test "new upload page states the removal consequence" do
    prepare_setup_complete_state
    sign_in_admin
    get new_admin_roster_import_path
    assert_response :success
    assert_select "h1", text: /Import roster/
    assert_select "body", text: /sign-in is turned off/
  end

  test "blank upload redirects back with alert" do
    prepare_setup_complete_state
    sign_in_admin

    post admin_roster_imports_path, params: { roster_import: {} }

    assert_redirected_to new_admin_roster_import_path
    assert_equal "Choose a roster CSV file to upload.", flash[:alert]
  end

  test "non-upload file param redirects back with alert" do
    prepare_setup_complete_state
    sign_in_admin

    post admin_roster_imports_path, params: { roster_import: { file: "not-a-file" } }

    assert_redirected_to new_admin_roster_import_path
    assert_equal "Choose a roster CSV file to upload.", flash[:alert]
  end

  test "malformed roster_import param redirects back with alert" do
    prepare_setup_complete_state
    sign_in_admin

    post admin_roster_imports_path, params: { roster_import: "not-a-hash" }

    assert_redirected_to new_admin_roster_import_path
    assert_equal "Choose a roster CSV file to upload.", flash[:alert]
  end

  test "successful upload creates people and shows import summary" do
    prepare_setup_complete_state
    sign_in_admin

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
    assert_select "h1", "Roster import complete"
    assert_select ".done-sub", /roster_valid\.csv/
    assert_select ".stat-tile--created .stat-n", "2"
  end

  test "large removal upload returns pending confirmation notice" do
    prepare_setup_complete_state
    sign_in_admin
    11.times do |index|
      person = Person.create!(first_name: "Gone", last_name: index.to_s, member_number: format("H%03d", index), roster_imported_at: 1.day.ago)
      User.create!(person: person, email_address: "controller-pending#{index}@example.com")
    end

    post admin_roster_imports_path, params: {
      roster_import: { file: fixture_file_upload("test/fixtures/files/roster_valid.csv", "text/csv") }
    }

    roster_import = RosterImport.order(:id).last
    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "Roster import requires confirmation before continuing.", flash[:alert]
    assert_equal "pending_confirmation", roster_import.status
  end

  test "upload with a missing member id row completes with a problem shown, no person created" do
    prepare_setup_complete_state
    sign_in_admin

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
    assert_select "h1", "Roster import complete"
    assert_select ".item", /Member ID/
  end

  test "index lists past imports newest first" do
    prepare_setup_complete_state
    sign_in_admin
    RosterImport.create!(status: "completed", imported_at: 2.days.ago, uploaded_filename: "old.csv")
    RosterImport.create!(status: "completed", imported_at: 1.hour.ago, uploaded_filename: "new.csv")

    get admin_roster_imports_path

    assert_response :success
    assert_select ".imp", minimum: 2
  end

  test "index renders a failed import whose problems are stored as plain strings" do
    prepare_setup_complete_state
    sign_in_admin
    RosterImport.create!(
      status: "failed", imported_at: 1.hour.ago, uploaded_filename: "broken.csv",
      summary: { "problems" => [ "Illegal quoting in line 1." ] }
    )

    get admin_roster_imports_path

    assert_response :success
    assert_select ".imp .l2", text: /Illegal quoting in line 1\./
  end

  test "show renders a failed import whose problems are stored as plain strings" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.create!(
      status: "failed", imported_at: 1.hour.ago, uploaded_filename: "broken.csv",
      problem_count: 1, summary: { "problems" => [ "Illegal quoting in line 1." ] }
    )

    get admin_roster_import_path(roster_import)

    assert_response :success
    assert_select ".item", text: /Illegal quoting in line 1\./
  end

  test "large removal upload shows pending confirmation and does not mutate records" do
    prepare_setup_complete_state
    sign_in_admin
    11.times do |index|
      person = Person.create!(first_name: "Gone", last_name: index.to_s, member_number: format("G%03d", index), roster_imported_at: 1.day.ago)
      User.create!(person: person, email_address: "controller-gone#{index}@example.com")
    end

    post admin_roster_imports_path, params: {
      roster_import: { file: fixture_file_upload("test/fixtures/files/roster_valid.csv", "text/csv") }
    }

    roster_import = RosterImport.order(:id).last
    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "pending_confirmation", roster_import.status
    assert_equal 0, Person.where.not(roster_removed_at: nil).count

    get admin_roster_import_path(roster_import)
    assert_response :success
    assert_select "h1", /Confirm roster import/
    assert_select "body", /This would remove 11 members/
    assert_select "input[type=checkbox][name=confirm_large_removal]"
  end

  test "confirming pending import requires checkbox" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.new(status: "pending_confirmation", imported_at: Time.current, uploaded_filename: "pending.csv", removed_count: 11)
    roster_import.pending_csv.attach(io: StringIO.new(file_fixture("roster_valid.csv").read), filename: "pending.csv", content_type: "text/csv")
    roster_import.save!

    post confirm_admin_roster_import_path(roster_import)

    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "Confirm the large removal before applying this import.", flash[:alert]
    assert_equal "pending_confirmation", roster_import.reload.status
  end

  test "confirm rejects completed imports without failing" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "done.csv", created_count: 0, updated_count: 0, unchanged_count: 0, removed_count: 0, problem_count: 0)

    post confirm_admin_roster_import_path(roster_import), params: { confirm_large_removal: "1" }

    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "That roster import can no longer be confirmed.", flash[:alert]
  end

  test "confirm rejects failed imports without failing" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.create!(status: "failed", imported_at: Time.current, uploaded_filename: "bad.csv", created_count: 0, updated_count: 0, unchanged_count: 0, removed_count: 0, problem_count: 1)

    post confirm_admin_roster_import_path(roster_import), params: { confirm_large_removal: "1" }

    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "That roster import can no longer be confirmed.", flash[:alert]
  end

  test "confirm rejects pending imports missing attachment without failing" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.new(status: "pending_confirmation", imported_at: Time.current, uploaded_filename: "pending.csv", created_count: 0, updated_count: 0, unchanged_count: 0, removed_count: 11, problem_count: 0)
    roster_import.save!(validate: false)

    post confirm_admin_roster_import_path(roster_import), params: { confirm_large_removal: "1" }

    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "That roster import can no longer be confirmed.", flash[:alert]
  end

  test "confirm rejects superseded pending imports and leaves them pending" do
    prepare_setup_complete_state
    sign_in_admin
    11.times do |index|
      person = Person.create!(first_name: "Gone", last_name: index.to_s, member_number: format("S%03d", index), roster_imported_at: 1.day.ago)
      User.create!(person: person, email_address: "superseded#{index}@example.com")
    end

    roster_import = RosterImport.new(status: "pending_confirmation", imported_at: Time.current, uploaded_filename: "pending.csv", removed_count: 11, problem_count: 0)
    roster_import.pending_csv.attach(io: StringIO.new(file_fixture("roster_valid.csv").read), filename: "pending.csv", content_type: "text/csv")
    roster_import.save!
    RosterImport.create!(status: "completed", imported_at: 1.minute.from_now, uploaded_filename: "newer.csv")

    post confirm_admin_roster_import_path(roster_import), params: { confirm_large_removal: "1" }

    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "That roster import can no longer be confirmed.", flash[:alert]
    assert_equal "pending_confirmation", roster_import.reload.status
    assert_equal 12, Person.where(roster_removed_at: nil).count
  end

  test "newer pending_confirmation import blocks old pending confirmation" do
    prepare_setup_complete_state
    sign_in_admin
    11.times do |index|
      person = Person.create!(first_name: "Gone", last_name: index.to_s, member_number: format("U%03d", index), roster_imported_at: 1.day.ago)
      User.create!(person: person, email_address: "supersede-pending#{index}@example.com")
    end

    old_import = RosterImport.new(status: "pending_confirmation", imported_at: 2.days.ago, uploaded_filename: "old.csv", removed_count: 11, problem_count: 0)
    old_import.pending_csv.attach(io: StringIO.new(file_fixture("roster_valid.csv").read), filename: "old.csv", content_type: "text/csv")
    old_import.save!

    newer_import = RosterImport.new(status: "pending_confirmation", imported_at: 1.day.ago, uploaded_filename: "newer.csv", removed_count: 11, problem_count: 0)
    newer_import.pending_csv.attach(io: StringIO.new(file_fixture("roster_valid.csv").read), filename: "newer.csv", content_type: "text/csv")
    newer_import.save!
    assert_operator newer_import.id, :>, old_import.id

    post confirm_admin_roster_import_path(old_import), params: { confirm_large_removal: "1" }

    assert_redirected_to admin_roster_import_path(old_import)
    assert_equal "That roster import can no longer be confirmed.", flash[:alert]
    assert_equal "pending_confirmation", old_import.reload.status
  end

  test "second confirm after success is rejected and leaves completed import unchanged" do
    prepare_setup_complete_state
    sign_in_admin
    11.times do |index|
      person = Person.create!(first_name: "Gone", last_name: index.to_s, member_number: format("T%03d", index), roster_imported_at: 1.day.ago)
      User.create!(person: person, email_address: "repeat#{index}@example.com")
    end

    pending = RosterImport.new(status: "pending_confirmation", imported_at: Time.current, uploaded_filename: "pending.csv", removed_count: 11, problem_count: 0)
    pending.pending_csv.attach(io: StringIO.new(file_fixture("roster_valid.csv").read), filename: "pending.csv", content_type: "text/csv")
    pending.save!

    post confirm_admin_roster_import_path(pending), params: { confirm_large_removal: "1" }
    assert_equal "completed", pending.reload.status

    post confirm_admin_roster_import_path(pending), params: { confirm_large_removal: "1" }

    assert_redirected_to admin_roster_import_path(pending)
    assert_equal "That roster import can no longer be confirmed.", flash[:alert]
    assert_equal "completed", pending.reload.status
  end

  test "pending show uses future tense for sign-in changes" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.new(status: "pending_confirmation", imported_at: Time.current, uploaded_filename: "pending.csv", removed_count: 11, problem_count: 0,
      summary: { "removal_confirmation" => { "removed_count" => 11, "sign_in_disable_count" => 1 }, "removed_members" => [ { "name" => "Gone Member", "member_number" => "000000000001", "would_disable_sign_in" => true } ] })
    roster_import.pending_csv.attach(io: StringIO.new(file_fixture("roster_valid.csv").read), filename: "pending.csv", content_type: "text/csv")
    roster_import.save!

    get admin_roster_import_path(roster_import)

    assert_response :success
    assert_select "body", text: /Sign-in would be turned off/
    assert_select "body", text: /Sign-in was turned off/, count: 0
  end

  test "completed show uses past tense for sign-in changes" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.new(status: "completed", imported_at: Time.current, uploaded_filename: "done.csv", removed_count: 1, problem_count: 0,
      summary: { "removed_members" => [ { "name" => "Gone Member", "member_number" => "000000000001", "user_disabled" => true } ] })
    roster_import.save!

    get admin_roster_import_path(roster_import)

    assert_response :success
    assert_select "body", text: /Sign-in was turned off/
    assert_select "body", text: /Sign-in would be turned off/, count: 0
  end

  test "show lists access effects and sign-in exceptions" do
    prepare_setup_complete_state
    sign_in_admin
    person = Person.create!(first_name: "Exception", last_name: "Member")
    User.create!(person: person, email_address: "exception@example.com", login_access_override: true, login_access_override_at: Time.current)
    roster_import = RosterImport.create!(
      status: "completed",
      imported_at: Time.current,
      uploaded_filename: "effects.csv",
      summary: { access_effects: { enabled_by_roster_status: 2, disabled_by_roster_status: 3, skipped_admin_override: 1, skipped_last_admin: 1 } }
    )

    get admin_roster_import_path(roster_import)

    assert_response :success
    assert_select "body", /Sign-in access/
    assert_select "body", /Turned on by roster status: 2/
    assert_select "body", /Turned off by roster status or removal: 3/
    assert_select "body", /Left as set manually: 1/
    assert_select "body", /Left on to protect the last administrator: 1/
    assert_select "body", /Sign-in exceptions/
    assert_select "body", /Exception Member/
  end

  test "pending show does not render the completed-style change tiles and offers a discard" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.new(status: "pending_confirmation", imported_at: Time.current, uploaded_filename: "pending.csv", removed_count: 11, problem_count: 0)
    roster_import.pending_csv.attach(io: StringIO.new(file_fixture("roster_valid.csv").read), filename: "pending.csv", content_type: "text/csv")
    roster_import.save!

    get admin_roster_import_path(roster_import)

    assert_response :success
    assert_select ".tiles", count: 0
    assert_select "input[type=checkbox][name=confirm_large_removal]"
    assert_select "form[action=?]", discard_admin_roster_import_path(roster_import)
  end

  test "discard turns a pending import inert without removing anyone" do
    prepare_setup_complete_state
    sign_in_admin
    11.times do |index|
      person = Person.create!(first_name: "Gone", last_name: index.to_s, member_number: format("D%03d", index), roster_imported_at: 1.day.ago)
      User.create!(person: person, email_address: "discard#{index}@example.com")
    end
    roster_import = RosterImport.new(status: "pending_confirmation", imported_at: Time.current, uploaded_filename: "pending.csv", removed_count: 11, problem_count: 0)
    roster_import.pending_csv.attach(io: StringIO.new(file_fixture("roster_valid.csv").read), filename: "pending.csv", content_type: "text/csv")
    roster_import.save!

    delete discard_admin_roster_import_path(roster_import)

    assert_redirected_to admin_roster_import_path(roster_import)
    assert_equal "Import discarded. No members were removed.", flash[:notice]
    assert_equal "discarded", roster_import.reload.status
    assert_equal 0, Person.where.not(roster_removed_at: nil).count

    get admin_roster_import_path(roster_import)
    assert_response :success
    assert_select "h1", /Import discarded/
    assert_select "input[type=checkbox][name=confirm_large_removal]", count: 0
  end

  test "discard leaves a completed import unchanged" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "done.csv", created_count: 0, updated_count: 0, unchanged_count: 0, removed_count: 0, problem_count: 0)

    delete discard_admin_roster_import_path(roster_import)

    assert_equal "completed", roster_import.reload.status
  end

  test "superseded pending show replaces the confirm form with a discard" do
    prepare_setup_complete_state
    sign_in_admin
    roster_import = RosterImport.new(status: "pending_confirmation", imported_at: Time.current, uploaded_filename: "old.csv", removed_count: 11, problem_count: 0)
    roster_import.pending_csv.attach(io: StringIO.new(file_fixture("roster_valid.csv").read), filename: "old.csv", content_type: "text/csv")
    roster_import.save!
    RosterImport.create!(status: "completed", imported_at: 1.minute.from_now, uploaded_filename: "newer.csv")

    get admin_roster_import_path(roster_import)

    assert_response :success
    assert_select "h1", /This import has been replaced/
    assert_select "input[type=checkbox][name=confirm_large_removal]", count: 0
    assert_select "form[action=?]", discard_admin_roster_import_path(roster_import)
  end

  private

  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_admin
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
  end
end
