require "test_helper"

class TrackedItemUpdateTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Adjutant"), email_address: "pat-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    @tracked_item = organization.tracked_items.create!(created_by: @user, title: "Buddy Checks")
  end

  test "requires meaningful update text" do
    update = @tracked_item.updates.build(author: @user, body: "")

    assert_not update.valid?
    assert_includes update.errors[:body], "can't be blank"
  end

  test "updates cannot be edited or deleted" do
    update = @tracked_item.updates.create!(author: @user, body: "Twenty calls remain.")

    assert_not update.update(body: "Changed history")
    assert_includes update.errors[:base], "Tracked item updates are append-only"
    assert_not update.destroy
    assert_includes update.errors[:base], "Tracked item updates are append-only"
    assert_includes update.reload.body.to_s, "Twenty calls remain."
  end
end
