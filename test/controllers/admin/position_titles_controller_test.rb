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
    adjutant = PositionTitle.create!(organization: @org, name: "Adjutant", display_order: 2, active: false)
    adjutant.position_capability_grants.create!(capability: "manage_minutes")

    get admin_position_titles_path

    assert_response :success
    assert_select ".pos .pn", text: "Commander"
    assert_select ".pos .pn", text: "Adjutant"
    assert_select ".position-access-note", text: /begins and ends with a dated assignment/
    assert_select ".pos-access", text: /Draft minutes/
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

  test "update can grant and remove full membership access" do
    prepare_setup_complete_state
    sign_in_admin
    title = PositionTitle.create!(organization: @org, name: "Membership Chair", display_order: 9)

    patch admin_position_title_path(title), params: { position_title: { grants_full_membership_access: "1" } }

    assert title.reload.grants_full_membership_access?
    assert_redirected_to admin_position_titles_path

    get admin_position_titles_path
    assert_select ".pos-access", text: /Full membership access/
    assert_select "input[type=submit][value=?], button", "Remove membership access"

    patch admin_position_title_path(title), params: { position_title: { grants_full_membership_access: "0" } }
    assert_not title.reload.grants_full_membership_access?
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

  test "update rejects a foreign Post title without changing its authority or assignments" do
    prepare_setup_complete_state
    sign_in_admin
    own = @org.position_titles.create!(name: "Configured Adjutant", display_order: 1)
    other = Organization.create!(name: "Separate synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.position_titles.create!(name: "Separate Post Adjutant", display_order: 1)
    foreign.position_capability_grants.create!(capability: "manage_minutes")
    person = Person.create!(first_name: "Separate", last_name: "Officer")
    foreign.position_assignments.create!(person: person, starts_on: Date.new(2026, 1, 1))
    original = position_graph(own, foreign)

    patch admin_position_title_path(foreign), params: {
      position_title: { name: "Changed foreign title", active: "0", grants_full_membership_access: "1" }
    }
    assert_equal original, position_graph(own, foreign)
    assert_response :not_found

    get admin_position_titles_path
    assert_response :success
    assert_select ".pos .pn", text: "Configured Adjutant"
    assert_select ".pos .pn", text: "Separate Post Adjutant", count: 0
    assert_select ".pos .pn", text: "Changed foreign title", count: 0
    patch admin_position_title_path(own), params: { position_title: { name: "Renamed configured Adjutant", active: "0" } }
    assert_equal "Renamed configured Adjutant", own.reload.name
    assert_not own.active?
    assert_redirected_to admin_position_titles_path
    assert_equal original.last, position_graph(foreign).last
  end

  private

  def position_graph(*titles)
    titles.map do |title|
      [ title.reload.attributes, title.position_capability_grants.order(:id).map(&:attributes),
        title.position_assignments.order(:id).map(&:attributes) ]
    end
  end
end
