require "test_helper"

class Admin::PositionTitlesControllerTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    @org = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_admin
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
  end

  test "create adds a position title for the organization" do
    prepare_setup_complete_state
    sign_in_admin
    assert_difference -> { PositionTitle.count }, 1 do
      post admin_position_titles_path, params: { position_title: { name: "Chaplain", display_order: 5 } }
    end
    assert_redirected_to admin_root_path
    assert_equal @org.id, PositionTitle.last.organization_id
  end

  test "update can deactivate a title" do
    prepare_setup_complete_state
    sign_in_admin
    title = PositionTitle.create!(organization: @org, name: "Historian", display_order: 9, active: true)
    patch admin_position_title_path(title), params: { position_title: { active: "0" } }
    assert_not title.reload.active
  end
end
