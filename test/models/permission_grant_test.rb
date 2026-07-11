require "test_helper"

class PermissionGrantTest < ActiveSupport::TestCase
  test "user can? returns true for granted capability and false for missing capability" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com")
    user.permission_grants.create!(capability: "manage_people")

    assert user.can?(:manage_people)
    assert_not user.can?(:manage_minutes)
  end
end
