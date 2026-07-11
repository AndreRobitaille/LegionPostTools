require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a unique person" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com")

    duplicate = User.new(person: person, email_address: "jane2@example.com")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:person_id], "has already been taken"
  end
end
