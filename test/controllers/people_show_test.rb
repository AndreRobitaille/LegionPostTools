require "test_helper"

class PeopleShowTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_officer
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
  end

  def sign_in_plain_member
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    sign_in_as(user)
  end

  def build_person
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent",
      roster_member_status: "Active", roster_paid_through_year: 2027, roster_email_address: "vincent@example.com",
      roster_phone_number: "555-1212", roster_branch: "U.S. Army", roster_war_era: "Vietnam", roster_continuous_years: 12,
      roster_undeliverable: false, roster_address: "123 Main St", roster_imported_at: Time.current)
  end

  test "officer sees the full record with login and role controls" do
    prepare_setup_complete_state
    sign_in_officer
    person = build_person
    user = User.create!(person: person, email_address: "vincent.alt@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_people")
    get person_path(person)
    assert_response :success
    assert_select "h1", "Alber, Vincent"
    assert_select ".card-head-label", text: /Roster Record/
    assert_select ".card-head-label", text: /Login Account/
    assert_select "input[type=email][name=?]", "user[email_address]", count: 0 # roster fields read-only
    assert_select "p", /123 Main St/ # officer sees address
    assert_select "form[action=?]", admin_user_permission_grants_path(user)
    assert_select "input[type=submit], button", text: /Disable sign-in/
  end

  test "officer login panel identifies admin override and revert action" do
    prepare_setup_complete_state
    sign_in_officer
    person = build_person
    User.create!(person: person, email_address: "override-panel@example.com", email_verified_at: Time.current, login_access_override: true, login_access_override_at: Time.current)

    get person_path(person)

    assert_response :success
    assert_includes response.body, "Sign-in is set manually."
    assert_select "input[type=submit], button", text: /Switch back to following the roster/
    assert_select "form[action=?]", roster_control_admin_person_user_account_path(person)
  end

  test "officer login panel shows roster-controlled state for a default account" do
    prepare_setup_complete_state
    sign_in_officer
    person = build_person
    User.create!(person: person, email_address: "roster-controlled@example.com", email_verified_at: Time.current)

    get person_path(person)

    assert_response :success
    assert_includes response.body, "Sign-in follows the National roster."
    assert_select "input[type=submit], button", text: /Switch back to following the roster/, count: 0
  end

  test "member sees contact, service, and roles but no record or controls" do
    prepare_setup_complete_state
    sign_in_plain_member
    person = build_person
    person.position_assignments.create!(
      position_title: PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1),
      starts_on: Date.new(2026, 1, 1)
    )
    get person_path(person)
    assert_response :success
    assert_select ".card-head-label", text: /Contact/
    assert_select ".card-head-label", text: /Service/
    assert_select ".card-head-label", text: /Post Roles/
    assert_select "a[href=?]", "mailto:vincent@example.com"
    assert_select ".card-head-label", text: /Roster Record/, count: 0
    assert_select ".card-head-label", text: /Login Account/, count: 0
    assert_select "body", text: /123 Main St/, count: 0 # address hidden from members
    assert_select "body", text: /000204540637/, count: 0 # member number hidden from members
    assert_select "body", text: /Active/, count: 0 # member status hidden from members
    assert_select "body", text: /Paid through/, count: 0 # paid-through hidden from members
  end

  test "manage_people officer sees officer view but not mutation forms" do
    prepare_setup_complete_state
    person_officer = Person.create!(first_name: "Pat", last_name: "Lee")
    officer_user = User.create!(person: person_officer, email_address: "pat@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: officer_user, capability: "manage_people")
    sign_in_as(officer_user)
    person = build_person
    get person_path(person)
    assert_response :success
    assert_select ".card-head-label", text: /Roster Record/
    assert_select "input[type=submit], button", text: /Disable sign-in/, count: 0
  end

  test "officer show loads position titles for the current organization" do
    prepare_setup_complete_state
    sign_in_officer
    person = build_person
    PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1)

    get person_path(person)

    assert_response :success
    assert_select "option", text: "Commander"
  end
end
