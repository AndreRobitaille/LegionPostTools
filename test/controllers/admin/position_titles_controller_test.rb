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

  test "index lists the post's positions" do
    prepare_setup_complete_state
    sign_in_admin
    PositionTitle.create!(organization: @org, name: "Commander", display_order: 1, active: true)
    PositionTitle.create!(organization: @org, name: "Adjutant", display_order: 2, active: false)

    get admin_position_titles_path

    assert_response :success
    assert_select ".pos .pn", text: "Commander"
    assert_select ".pos .pn", text: "Adjutant"
    assert_select "a[href=?]", admin_root_path, text: /Back to Administration/
  end

  test "index requires manage_settings" do
    prepare_setup_complete_state
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_agendas")
    sign_in_as(user)

    get admin_position_titles_path

    assert_redirected_to root_path
  end

  test "create appends the position to the end and ignores any submitted order" do
    prepare_setup_complete_state
    sign_in_admin
    PositionTitle.create!(organization: @org, name: "Commander", display_order: 3, active: true)

    assert_difference -> { PositionTitle.count }, 1 do
      post admin_position_titles_path, params: { position_title: { name: "Chaplain", display_order: 1 } }
    end

    assert_redirected_to admin_position_titles_path
    created = PositionTitle.find_by!(name: "Chaplain")
    assert_equal @org.id, created.organization_id
    assert_equal 4, created.display_order
  end

  test "update can deactivate a title" do
    prepare_setup_complete_state
    sign_in_admin
    title = PositionTitle.create!(organization: @org, name: "Historian", display_order: 9, active: true)
    patch admin_position_title_path(title), params: { position_title: { active: "0" } }
    assert_not title.reload.active
    assert_redirected_to admin_position_titles_path
  end

  test "reorder persists the new order" do
    prepare_setup_complete_state
    sign_in_admin
    a = PositionTitle.create!(organization: @org, name: "Commander", display_order: 1)
    b = PositionTitle.create!(organization: @org, name: "Adjutant", display_order: 2)
    c = PositionTitle.create!(organization: @org, name: "Chaplain", display_order: 3)

    post reorder_admin_position_titles_path, params: { ids: [ c.id, a.id, b.id ] }, as: :json

    assert_response :success
    assert_equal 1, c.reload.display_order
    assert_equal 2, a.reload.display_order
    assert_equal 3, b.reload.display_order
  end

  test "reorder rejects ids from another organization" do
    prepare_setup_complete_state
    sign_in_admin
    a = PositionTitle.create!(organization: @org, name: "Commander", display_order: 1)
    other_org = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = PositionTitle.create!(organization: other_org, name: "Historian", display_order: 1)

    post reorder_admin_position_titles_path, params: { ids: [ a.id, foreign.id ] }, as: :json

    assert_response :unprocessable_entity
    assert_equal 1, a.reload.display_order
  end
end
