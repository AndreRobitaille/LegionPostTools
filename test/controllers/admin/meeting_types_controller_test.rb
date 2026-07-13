require "test_helper"

class Admin::MeetingTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  test "signed out users are redirected" do
    get admin_meeting_types_path

    assert_redirected_to new_session_path
  end

  test "users without manage_agendas are denied" do
    sign_in_as(user_with_capabilities)

    get admin_meeting_types_path

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "index seeds and lists meeting types" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get admin_meeting_types_path

    assert_response :success
    assert_select "h1", text: /Meeting Types/
    assert_select "a[href=?]", admin_agenda_item_catalog_entries_path, text: /Agenda Item Catalog/
    assert_select "body", text: /PEC Meeting/
    assert_select "body", text: /Membership Meeting/
  end

  test "create meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    assert_difference -> { @organization.meeting_types.count }, 3 do
      post admin_meeting_types_path, params: { meeting_type: { name: "Special Ceremony Meeting", active: true } }
    end

    meeting_type = @organization.meeting_types.find_by!(slug: "special-ceremony-meeting")
    assert_redirected_to edit_admin_meeting_type_path(meeting_type)
    assert_equal "Meeting type created.", flash[:notice]
  end

  test "create seeds defaults before assigning next position on a fresh organization" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    post admin_meeting_types_path, params: { meeting_type: { name: "Special Ceremony Meeting", active: true } }

    meeting_type = @organization.meeting_types.find_by!(slug: "special-ceremony-meeting")
    assert_equal 3, meeting_type.position
    assert_equal [ "PEC Meeting", "Membership Meeting", "Special Ceremony Meeting" ], @organization.meeting_types.ordered.pluck(:name)
  end

  test "newly created meeting type appends after seeded defaults" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    get admin_meeting_types_path

    post admin_meeting_types_path, params: { meeting_type: { name: "Special Ceremony Meeting", active: true } }

    meeting_type = @organization.meeting_types.find_by!(slug: "special-ceremony-meeting")
    assert_equal 3, meeting_type.position
    assert_equal [ "PEC Meeting", "Membership Meeting", "Special Ceremony Meeting" ], @organization.meeting_types.ordered.pluck(:name)
  end

  test "invalid create returns unprocessable entity" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    post admin_meeting_types_path, params: { meeting_type: { name: "", active: true } }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Name can't be blank/
  end

  test "update meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    meeting_type = @organization.meeting_types.create!(name: "Old Name", position: 1, active: true)

    patch admin_meeting_type_path(meeting_type), params: { meeting_type: { name: "New Name", active: false } }

    assert_redirected_to edit_admin_meeting_type_path(meeting_type)
    assert_equal "Meeting type updated.", flash[:notice]
    assert_equal "New Name", meeting_type.reload.name
    assert_not meeting_type.active?
  end

  test "invalid update returns unprocessable entity" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    patch admin_meeting_type_path(meeting_type), params: { meeting_type: { name: "", active: false } }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Name can't be blank/
  end

  test "edit form hides developer fields" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    get edit_admin_meeting_type_path(meeting_type)

    assert_response :success
    assert_select "input[name=?]", "meeting_type[name]"
    assert_select "input[name=?]", "meeting_type[active]"
    assert_select "input[name=?]", "meeting_type[slug]", count: 0
    assert_select "input[name=?]", "meeting_type[position]", count: 0
  end

  test "cannot edit another organization meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    meeting_type = other.meeting_types.create!(name: "Other Meeting", position: 1, active: true)

    get edit_admin_meeting_type_path(meeting_type)

    assert_response :not_found
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
