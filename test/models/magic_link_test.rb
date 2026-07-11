require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  test "fresh unused token can be consumed once" do
    user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Doe"), email_address: "jane@example.com")
    magic_link = MagicLink.create_for!(user)

    assert_equal user, MagicLink.consume!(magic_link.token)
    assert_nil MagicLink.consume!(magic_link.token)
    assert_not_nil magic_link.reload.used_at
  end

  test "expired token cannot be consumed" do
    user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Doe"), email_address: "jane@example.com")
    magic_link = MagicLink.create_for!(user)
    magic_link.update!(expires_at: 1.minute.ago)

    assert_nil MagicLink.consume!(magic_link.token)
  end
end
