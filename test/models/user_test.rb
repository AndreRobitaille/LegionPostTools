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
end
