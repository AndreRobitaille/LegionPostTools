require "application_system_test_case"

class RosterImportResultsSystemTest < ApplicationSystemTestCase
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
      page.save_screenshot(Rails.root.join("tmp/screenshots/roster-results-#{width}.png"))
      page.execute_script("arguments[0].scrollIntoView({block: 'start'})", find(".card", text: /Sign-in access/i))
      page.save_screenshot(Rails.root.join("tmp/screenshots/roster-accounts-#{width}.png"))
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
