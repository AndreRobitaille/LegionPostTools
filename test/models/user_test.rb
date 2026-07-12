require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a unique person" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com")

    duplicate = User.new(person: person, email_address: "jane2@example.com")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:person_id], "has already been taken"
  end

  test "detects unresolved roster email mismatch" do
    person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
    user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

    assert user.roster_email_mismatch?
    assert user.needs_roster_email_review?
  end

  test "does not prompt again after keeping current login email for same roster email" do
    person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
    user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

    user.keep_current_login_email!

    assert user.roster_email_mismatch?
    assert_not user.needs_roster_email_review?
  end

  test "prompts again after remind me later" do
    person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
    user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

    user.remind_later_about_roster_email!

    assert user.needs_roster_email_review?
  end

  def admin(email)
    u = User.create!(person: Person.create!(first_name: email, last_name: "X"), email_address: "#{email}@x.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: u, capability: "manage_settings")
    u
  end

  test "only_enabled_administrator? is true when this is the sole enabled admin" do
    a = admin("a")
    assert a.only_enabled_administrator?
  end

  test "only_enabled_administrator? is false when another enabled admin exists" do
    a = admin("a")
    admin("b")
    assert_not a.only_enabled_administrator?
  end

  test "another_enabled_manage_settings_user_exists? ignores the given user and disabled users" do
    a = admin("a")
    b = admin("b")
    assert User.another_enabled_manage_settings_user_exists?(a)
    b.update!(disabled_at: Time.current)
    assert_not User.another_enabled_manage_settings_user_exists?(a)
  end
end
