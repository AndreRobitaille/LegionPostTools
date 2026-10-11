require "application_system_test_case"

class RosterImportResultsSystemTest < ApplicationSystemTestCase
  test "empty file upload preserves members and a later valid upload works" do
    Organization.create!(name: "Synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    admin = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Administrator"), email_address: "upload-admin@example.test")
    admin.permission_grants.create!(capability: "manage_settings")
    member = Person.create!(first_name: "Existing", last_name: "Member", member_number: "000204540637",
      roster_member_status: "Active", roster_address: "Original synthetic address", roster_imported_at: 3.days.ago)
    user = User.create!(person: member, email_address: "private-upload-login@example.test")
    system_sign_in(admin)
    original = [ Person.order(:id).map(&:attributes), User.order(:id).map(&:attributes), PermissionGrant.order(:id).map(&:attributes) ]

    visit new_admin_roster_import_path
    attach_file "Choose the roster CSV file", file_fixture("roster_empty.csv")
    click_button "Upload and import"
    assert_selector "h1", text: "Roster import could not be completed"
    assert_equal original, [ Person.order(:id).map(&:attributes), User.order(:id).map(&:attributes), PermissionGrant.order(:id).map(&:attributes) ]
    failed = RosterImport.order(:id).last
    assert_equal "failed", failed.status
    assert_current_path admin_roster_import_path(failed)
    assert_text "Missing required columns"
    capture_upload_layout("failed")

    click_link "Import another roster"
    assert_selector "h1", text: "Import roster"
    attach_file "Choose the roster CSV file", file_fixture("roster_valid.csv")
    click_button "Upload and import"
    assert_selector "h1", text: "Roster import complete"
    completed = RosterImport.order(:id).last
    assert_equal "completed", completed.status
    assert_equal [ 1, 1, 0 ], [ completed.created_count, completed.updated_count, completed.removed_count ]
    assert_equal "123 Main St", member.reload.roster_address
    assert_equal "private-upload-login@example.test", user.reload.email_address
    assert_not_nil Person.find_by!(member_number: "000204540638").user
    assert_current_path admin_roster_import_path(completed)
    capture_upload_layout("completed")
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "import results identify new accounts and warn about deceased status changes at desktop and narrow widths" do
    Organization.create!(name: "Synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    admin = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Administrator"), email_address: "roster-admin@example.test")
    admin.permission_grants.create!(capability: "manage_settings")
    Person.create!(first_name: "Alex", last_name: "Example", member_number: "STATUS1",
      roster_member_status: "Deceased", roster_imported_at: 1.day.ago)
    csv = CSV.generate do |output|
      output << RosterImports::CsvParser::REQUIRED_HEADERS
      output << [ "STATUS1", "Example, Alex", 165, "Member", "", "", "alex@example.test", "", "", "", 1, 2026, "Active" ]
      12.times do |index|
        output << [ "NEW#{index}", "Member, New #{index}", 165, "Member", "", "", "new#{index}@example.test", "", "", "", 1, 2026, "Active" ]
      end
    end
    result = RosterImports::Importer.new(csv_text: csv, filename: "synthetic-roster.csv").import
    assert result.success?
    system_sign_in(admin)

    visit admin_roster_import_path(result.roster_import)

    assert_selector ".card--alert", text: /Check deceased member status/i
    assert_selector ".card--alert", text: "Example, Alex"
    assert_text "New accounts created and enabled: 13"
    assert_text "New roster record: Member, New 11"
    assert_link "View record", href: person_path(Person.find_by!(member_number: "STATUS1"))
    [ [ 1400, 1400 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth"), "Overflow at #{width}px"
      page.execute_script("window.scrollTo(0, 0)")
      capture_system_screenshot("roster-results-#{width}")
      page.execute_script("arguments[0].scrollIntoView({block: 'start'})", find(".card", text: /Sign-in access/i))
      capture_system_screenshot("roster-accounts-#{width}")
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def capture_upload_layout(state)
    [ [ 1400, 1400 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth"), "Roster #{state} overflow at #{width}px"
      capture_system_screenshot("roster-upload-#{state}-#{width}")
    end
  end
end
