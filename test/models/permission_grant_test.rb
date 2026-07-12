require "test_helper"

class PermissionGrantTest < ActiveSupport::TestCase
  test "user can? returns true for granted capability and false for missing capability" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com")
    user.permission_grants.create!(capability: "manage_people")

    assert user.can?(:manage_people)
    assert_not user.can?(:manage_minutes)
  end

  test "GROUPS covers every capability exactly once in order" do
    grouped = PermissionGrant::GROUPS.flat_map { |(_label, caps)| caps }
    assert_equal PermissionGrant::CAPABILITIES.sort, grouped.sort
    assert_equal grouped, grouped.uniq
    assert_equal "Administration", PermissionGrant::GROUPS.first.first
  end
end
