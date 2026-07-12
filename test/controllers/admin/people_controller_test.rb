require "test_helper"

class Admin::PeopleControllerTest < ActionDispatch::IntegrationTest
  test "index lists imported members" do
    prepare_setup_complete_state
    sign_in_member
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    Person.create!(first_name: "Jane", last_name: "Roe", member_number: "000204540638", roster_name: "Roe, Jane")

    get admin_people_path

    assert_response :success
    assert_select "h1", "People"
    assert_select "table", text: /Alber, Vincent/
  end

  test "index search includes matching person and excludes non-match" do
    prepare_setup_complete_state
    sign_in_member
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    Person.create!(first_name: "Jane", last_name: "Roe", member_number: "000204540638", roster_name: "Roe, Jane")

    get admin_people_path, params: { q: "Vincent" }

    assert_response :success
    assert_select "table", text: /Alber, Vincent/
    assert_select "table", text: /Roe, Jane/, count: 0
  end

  test "index shows disabled login status for linked user" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    User.create!(person: person, email_address: "vincent@example.com", email_verified_at: Time.current, disabled_at: Time.current)

    get admin_people_path

    assert_response :success
    assert_select "table", text: /Disabled/
  end

  test "index filters by member status" do
    prepare_setup_complete_state
    sign_in_member
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_member_status: "Active")
    Person.create!(first_name: "Jane", last_name: "Roe", member_number: "000204540638", roster_name: "Roe, Jane", roster_member_status: "Inactive")

    get admin_people_path, params: { roster_member_status: "Active" }

    assert_response :success
    assert_select "table", text: /Alber, Vincent/
    assert_select "table", text: /Roe, Jane/, count: 0
  end

  test "index filters by paid through year" do
    prepare_setup_complete_state
    sign_in_member
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_paid_through_year: 2027)
    Person.create!(first_name: "Jane", last_name: "Roe", member_number: "000204540638", roster_name: "Roe, Jane", roster_paid_through_year: 2026)

    get admin_people_path, params: { roster_paid_through_year: 2027 }

    assert_response :success
    assert_select "table", text: /Alber, Vincent/
    assert_select "table", text: /Roe, Jane/, count: 0
  end

  test "index filters by branch" do
    prepare_setup_complete_state
    sign_in_member
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_branch: "Army")
    Person.create!(first_name: "Jane", last_name: "Roe", member_number: "000204540638", roster_name: "Roe, Jane", roster_branch: "Navy")

    get admin_people_path, params: { roster_branch: "Army" }

    assert_response :success
    assert_select "table", text: /Alber, Vincent/
    assert_select "table", text: /Roe, Jane/, count: 0
  end

  test "index filters by login status no login" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    Person.create!(first_name: "Jane", last_name: "Roe", member_number: "000204540638", roster_name: "Roe, Jane")
    User.create!(person: person, email_address: "vincent@example.com", email_verified_at: Time.current)

    get admin_people_path, params: { login_status: "no_login" }

    assert_response :success
    assert_select "table", text: /Roe, Jane/
    assert_select "table", text: /Alber, Vincent/, count: 0
  end

  test "index filters by enabled login status" do
    prepare_setup_complete_state
    sign_in_member
    enabled_person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    disabled_person = Person.create!(first_name: "Jane", last_name: "Roe", member_number: "000204540638", roster_name: "Roe, Jane")
    User.create!(person: enabled_person, email_address: "vincent.enabled@example.com", email_verified_at: Time.current)
    User.create!(person: disabled_person, email_address: "jane.disabled@example.com", email_verified_at: Time.current, disabled_at: Time.current)

    get admin_people_path, params: { login_status: "enabled" }

    assert_response :success
    assert_select "table", text: /Alber, Vincent/
    assert_select "table", text: /Roe, Jane/, count: 0
  end

  test "index filters by disabled login status" do
    prepare_setup_complete_state
    sign_in_member
    enabled_person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    disabled_person = Person.create!(first_name: "Jane", last_name: "Roe", member_number: "000204540638", roster_name: "Roe, Jane")
    User.create!(person: enabled_person, email_address: "vincent.enabled@example.com", email_verified_at: Time.current)
    User.create!(person: disabled_person, email_address: "jane.disabled@example.com", email_verified_at: Time.current, disabled_at: Time.current)

    get admin_people_path, params: { login_status: "disabled" }

    assert_response :success
    assert_select "table", text: /Roe, Jane/
    assert_select "table", text: /Alber, Vincent/, count: 0
  end

  test "show renders read-only roster detail" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(
      first_name: "Vincent",
      last_name: "Alber",
      member_number: "000204540637",
      roster_name: "Alber, Vincent",
      roster_post: "Post 165",
      roster_membership_type: "Member",
      roster_member_status: "Active",
      roster_paid_through_year: 2027,
      roster_email_address: "vincent@example.com",
      roster_phone_number: "555-1212",
      roster_branch: "Army",
      roster_war_era: "Vietnam",
      roster_continuous_years: 12,
      roster_undeliverable: false,
      roster_address: "123 Main St",
      roster_imported_at: Time.current
    )

    get admin_person_path(person)

    assert_response :success
    assert_select "h1", "Alber, Vincent"
    assert_select "dt", "Member ID"
    assert_select "dd", "000204540637"
    assert_select "input[name=?]", "person[roster_email_address]", count: 0
  end

  test "show renders login account controls for linked user" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_email_address: "vincent@example.com")
    user = User.create!(person: person, email_address: "vincent.alt@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_people")

    get admin_person_path(person)

    assert_response :success
    assert_select "h2", "Login account"
    assert_select "p", /Email: vincent\.alt@example\.com/
    assert_select "p", /Status: Enabled/
    assert_select "p", /Roster email address does not match the login email address\./
    assert_select "input[type=submit][value=?]", "Update permissions"
    assert_select "form button", "Disable login"
  end

  test "show renders enabled login form with nested email parameter" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_email_address: "vincent@example.com")

    get admin_person_path(person)

    assert_response :success
    assert_select "form[action=?] input[type=email][name=?]", admin_person_user_account_path(person), "user[email_address]"
  end

  test "show renders re-enable login controls for disabled linked user" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_email_address: "vincent@example.com")
    user = User.create!(person: person, email_address: "vincent.alt@example.com", email_verified_at: Time.current, disabled_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_people")

    get admin_person_path(person)

    assert_response :success
    assert_select "h2", "Login account"
    assert_select "p", /Status: Disabled/
    assert_select "input[type=email][value=?]", "vincent.alt@example.com"
    assert_select "input[type=submit][value=?]", "Re-enable login"
  end

  test "show renders re-enable login form with nested email parameter" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_email_address: "vincent@example.com")
    User.create!(person: person, email_address: "vincent.alt@example.com", email_verified_at: Time.current, disabled_at: Time.current)

    get admin_person_path(person)

    assert_response :success
    assert_select "form[action=?] input[type=email][name=?]", admin_person_user_account_path(person), "user[email_address]"
  end

  test "show renders post roles section with assignment controls" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    commander = PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1)
    person.position_assignments.create!(position_title: commander, starts_on: Date.new(2026, 7, 1))

    get admin_person_path(person)

    assert_response :success
    assert_select "h2", "Post roles"
    assert_select "li", /Commander/
    assert_select "form[action=?] input[type=date][name=?]", admin_person_position_assignments_path(person), "position_assignment[starts_on]"
    assert_select "input[type=submit][value=?]", "Assign role"
    assert_select "input[type=submit][value=?]", "End role"
  end

  test "show renders end role form with nested ends on parameter" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    commander = PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1)
    assignment = person.position_assignments.create!(position_title: commander, starts_on: Date.new(2026, 7, 1))

    get admin_person_path(person)

    assert_response :success
    assert_select "form[action=?] input[type=date][name=?]", admin_person_position_assignment_path(person, assignment), "position_assignment[ends_on]"
  end

  test "show only offers active position titles for assignment" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    active_title = PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 2, active: true)
    inactive_title = PositionTitle.create!(organization: Organization.first, name: "Adjutant", display_order: 1, active: false)

    get admin_person_path(person)

    assert_response :success
    assert_select "select[name=?] option", "position_assignment[position_title_id]", text: active_title.name
    assert_select "select[name=?] option[value=?]", "position_assignment[position_title_id]", inactive_title.id, count: 0
  end

  test "show orders active position titles by display order then name for assignment" do
    prepare_setup_complete_state
    sign_in_member
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent")
    later_title = PositionTitle.create!(organization: Organization.first, name: "Quartermaster", display_order: 2, active: true)
    first_title = PositionTitle.create!(organization: Organization.first, name: "Adjutant", display_order: 1, active: true)
    same_order_later_name = PositionTitle.create!(organization: Organization.first, name: "Zeta", display_order: 2, active: true)

    get admin_person_path(person)

    assert_response :success
    assert_select "select[name=?] option", "position_assignment[position_title_id]" do |options|
      assert_equal [ "Adjutant", "Quartermaster", "Zeta" ], options.map { |option| option.text.strip }
    end
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
