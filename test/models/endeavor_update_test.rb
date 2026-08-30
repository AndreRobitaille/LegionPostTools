require "test_helper"

class EndeavorUpdateTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Adjutant"), email_address: "pat-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    @endeavor = organization.endeavors.create!(created_by: @user, title: "Buddy Checks")
  end

  test "requires meaningful update text" do
    update = @endeavor.updates.build(author: @user, body: "")

    assert_not update.valid?
    assert_includes update.errors[:body], "can't be blank"
  end

  test "updates cannot be edited or deleted" do
    update = @endeavor.updates.create!(author: @user, body: "Twenty calls remain.")

    assert_not update.update(body: "Changed history")
    assert_includes update.errors[:base], "Endeavor updates are append-only"
    assert_not update.destroy
    assert_includes update.errors[:base], "Endeavor updates are append-only"
    assert_includes update.reload.body.to_s, "Twenty calls remain."
  end
end
