require "test_helper"

class TrackedItemUpdatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @manager = create_user("Manager", manage_agendas: true)
    @member = create_user("Member")
    @tracked_item = @organization.tracked_items.create!(created_by: @manager, title: "Buddy Checks")
  end

  test "manager adds an append-only update" do
    sign_in_as(@manager)

    assert_difference -> { @tracked_item.updates.count }, 1 do
      post tracked_item_updates_path(@tracked_item), params: { tracked_item_update: { body: "Five calls were completed." } }
    end

    update = @tracked_item.updates.first
    assert_redirected_to tracked_item_path(@tracked_item)
    assert_equal @manager, update.author
    assert_includes update.body.to_s, "Five calls were completed."
  end

  test "blank update gives plain guidance" do
    sign_in_as(@manager)

    assert_no_difference -> { @tracked_item.updates.count } do
      post tracked_item_updates_path(@tracked_item), params: { tracked_item_update: { body: "" } }
    end

    assert_redirected_to tracked_item_path(@tracked_item)
    assert_equal "Body can't be blank", flash[:alert]
  end

  test "plain member cannot add an update" do
    sign_in_as(@member)

    assert_no_difference -> { @tracked_item.updates.count } do
      post tracked_item_updates_path(@tracked_item), params: { tracked_item_update: { body: "Not allowed" } }
    end

    assert_redirected_to root_path
  end

  private

  def create_user(label, manage_agendas: false)
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_agendas") if manage_agendas
    user
  end
end
