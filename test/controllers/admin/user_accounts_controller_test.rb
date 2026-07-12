require "test_helper"

class Admin::UserAccountsControllerTest < ActionDispatch::IntegrationTest
  test "creates user login for person using roster email by default" do
    person = prepare_admin_person(roster_email_address: "vincent@example.com")

    post admin_person_user_account_path(person)

    assert_redirected_to admin_person_path(person)
    assert_equal "Login account is enabled.", flash[:notice]
    assert_equal "vincent@example.com", person.reload.user.email_address
    assert person.user.email_verified_at.present?
    assert_nil person.user.disabled_at
  end

  test "uses admin-entered email when enabling login" do
    person = prepare_admin_person(roster_email_address: "vincent@example.com")

    post admin_person_user_account_path(person), params: { user: { email_address: "admin@example.com" } }

    assert_redirected_to admin_person_path(person)
    assert_equal "Login account is enabled.", flash[:notice]
    assert_equal "admin@example.com", person.reload.user.email_address
  end

  test "re-enables disabled existing user with admin-entered email" do
    person = prepare_admin_person(roster_email_address: "vincent@example.com")
    user = User.create!(person: person, email_address: "old@example.com", email_verified_at: Time.current, disabled_at: Time.current)

    post admin_person_user_account_path(person), params: { user: { email_address: "new@example.com" } }

    assert_redirected_to admin_person_path(person)
    assert_equal "Login account is enabled.", flash[:notice]
    assert_equal user.id, person.reload.user.id
    assert_equal "new@example.com", person.user.email_address
    assert_nil person.user.disabled_at
  end

  test "disables user login" do
    person = prepare_admin_person(roster_email_address: "vincent@example.com")
    user = User.create!(person: person, email_address: "vincent@example.com", email_verified_at: Time.current)

    delete admin_person_user_account_path(person)

    assert_redirected_to admin_person_path(person)
    assert_equal "Login account is disabled.", flash[:notice]
    assert person.reload.user.disabled_at.present?
    assert_equal user.id, person.user.id
  end

  test "cannot disable only enabled manage_settings user" do
    person = prepare_admin_person(roster_email_address: "vincent@example.com", sign_in_as_target: true)

    delete admin_person_user_account_path(person)

    assert_redirected_to admin_person_path(person)
    assert_equal "At least one enabled administrator account is required.", flash[:alert]
    assert_nil person.reload.user.disabled_at
  end

  test "can disable one admin when another enabled manage_settings user exists" do
    person = prepare_admin_person(roster_email_address: "vincent@example.com")
    User.create!(person: person, email_address: "vincent@example.com", email_verified_at: Time.current)
    other_person = Person.create!(first_name: "Other", last_name: "Admin")
    other_user = User.create!(person: other_person, email_address: "other@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: other_user, capability: "manage_settings")

    delete admin_person_user_account_path(person)

    assert_redirected_to admin_person_path(person)
    assert_equal "Login account is disabled.", flash[:notice]
    assert person.reload.user.disabled_at.present?
  end

  test "blank email with no roster email redirects with the blank-email alert" do
    person = prepare_admin_person

    post admin_person_user_account_path(person), params: { user: { email_address: "" } }

    assert_redirected_to admin_person_path(person)
    assert_equal "Enter a login email address before creating the account.", flash[:alert]
    assert_nil person.reload.user
  end

  private

  def prepare_admin_person(roster_email_address: nil, sign_in_as_target: false)
    prepare_setup_complete_state
    if sign_in_as_target
      sign_in_manage_settings_admin(first_name: "Vincent", last_name: "Alber", email_address: roster_email_address)
      Person.find_by!(first_name: "Vincent", last_name: "Alber")
    else
      sign_in_manage_settings_admin
      Person.create!(first_name: "Vincent", last_name: "Alber", roster_email_address: roster_email_address)
    end
  end

  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_manage_settings_admin(first_name: "Jane", last_name: "Doe", email_address: "jane@example.com")
    person = Person.create!(first_name: first_name, last_name: last_name)
    user = User.create!(person: person, email_address: email_address, email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
    person
  end
end
