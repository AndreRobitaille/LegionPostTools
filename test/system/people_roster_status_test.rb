require "application_system_test_case"
require "tempfile"

class PeopleRosterStatusSystemTest < ApplicationSystemTestCase
  test "officer sees removal for people with and without accounts and a later import restores current standing" do
    Organization.create!(name: "Synthetic roster Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    admin = User.create!(person: Person.create!(first_name: "Roster", last_name: "Administrator"), email_address: "roster-admin@example.test")
    admin.permission_grants.create!(capability: "manage_settings")
    former = Person.create!(first_name: "Former", last_name: "Alton", roster_name: "Alton, Former", member_number: "FORMER1",
      roster_member_status: "Active", roster_paid_through_year: 2026, roster_imported_at: 2.days.ago)
    junior = Person.create!(first_name: "Junior", last_name: "Alton", roster_name: "Alton, Junior", member_number: "FORMER2",
      roster_member_status: "Active", roster_paid_through_year: 2026, roster_imported_at: 2.days.ago)
    login = User.create!(person: former, email_address: "former-login@example.test")
    system_sign_in(admin)

    visit new_admin_roster_import_path
    attach_file "Choose the roster CSV file", file_fixture("roster_valid.csv")
    click_button "Upload and import"
    assert_selector "h1", text: "Roster import complete"
    assert_equal 2, RosterImport.latest_successful.removed_count
    assert_equal "roster_removed", login.reload.disabled_reason
    assert_nil junior.reload.user

    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, width == 1400 ? 1400 : 844)
      visit people_path(q: "Alton")
      assert_selector ".mrow .st--other", text: "Removed from roster", count: 2
      assert_no_selector ".mrow .st--active"
      assert_text "Sign-in: No account"
      assert_text "not on the latest National roster"
      assert_no_overflow(width)
      capture_system_screenshot("removed-people-#{width}")

      click_link "Alton, Junior"
      assert_selector ".idmeta .st--other", text: "Removed from roster"
      assert_text "Removed from the National roster"
      assert_selector ".kv", text: /Last imported status.*Active/im
      assert_no_overflow(width)
      capture_system_screenshot("removed-person-#{width}")
      page.execute_script("arguments[0].scrollIntoView({block: 'center'})", find(".acct-mode--off"))
      assert_text "Creating an account will keep sign-in off"
      capture_system_screenshot("removed-person-account-#{width}")

      visit people_path(q: "Alton")
      select "Active", from: "Member status"
      click_button "Apply filters"
      assert_text "No members found"
      select "Removed from roster", from: "Member status"
      click_button "Apply filters"
      assert_selector ".mrow .st--other", text: "Removed from roster", count: 2
    end

    returning_csv = file_fixture("roster_valid.csv").read
    [ former, junior ].each do |person|
      returning_csv += CSV.generate_line([ person.member_number, person.roster_name, 165, "Member", "", "", "", "", "", "", 1, 2026, "Active" ])
    end
    Tempfile.create([ "synthetic-returning-roster", ".csv" ]) do |file|
      file.write(returning_csv)
      file.flush
      visit new_admin_roster_import_path
      attach_file "Choose the roster CSV file", file.path
      click_button "Upload and import"
      assert_selector "h1", text: "Roster import complete"
    end
    visit people_path(q: "Alton", roster_member_status: "Active")
    assert_selector ".mrow .st--active", text: "Active", count: 2
    assert_no_text "Removed from roster"
    assert_nil former.reload.roster_removed_at
    assert_nil junior.reload.roster_removed_at
    assert_nil login.reload.disabled_at
    assert_equal "former-login@example.test", login.email_address
    visit person_path(junior)
    assert_no_selector ".kv .k", text: /Last imported status/i
    assert_selector ".idmeta .st--active", text: "Active"
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def assert_no_overflow(width)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth"), "Overflow at #{width}px"
  end
end
