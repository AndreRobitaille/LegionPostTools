require "test_helper"

class Admin::MeetingTypeAgendaSectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @section = @meeting_type.default_agenda_section
  end

  test "section management requires manage_agendas" do
    sign_in_as(user_with_capabilities)

    get new_admin_meeting_type_agenda_section_path(@meeting_type)

    assert_redirected_to root_path
  end

  test "authorized officers can create and rename a section" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    assert_difference -> { @meeting_type.meeting_type_agenda_sections.count }, 1 do
      post admin_meeting_type_agenda_sections_path(@meeting_type), params: { meeting_type_agenda_section: { title: "Post Business" } }
    end
    section = @meeting_type.meeting_type_agenda_sections.find_by!(title: "Post Business")
    assert_equal 2, section.position

    patch admin_meeting_type_agenda_section_path(@meeting_type, section), params: { meeting_type_agenda_section: { title: "New Business" } }
    assert_equal "New Business", section.reload.title
  end

  test "invalid section renders the designed form" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    post admin_meeting_type_agenda_sections_path(@meeting_type), params: { meeting_type_agenda_section: { title: "" } }

    assert_response :unprocessable_entity
    assert_select ".section-form-panel .error-summary", text: /Title can't be blank/
  end

  test "reorder rejects foreign section ids" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    second = @meeting_type.meeting_type_agenda_sections.create!(title: "Post Business", position: 2)
    other_type = @organization.meeting_types.create!(name: "PEC Meeting", position: 2, active: true)

    post reorder_admin_meeting_type_agenda_sections_path(@meeting_type), params: { ids: [ second.id, other_type.default_agenda_section.id ] }, as: :json

    assert_response :unprocessable_entity
    assert_equal 1, @section.reload.position
  end

  test "move changes the section order one position at a time" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    second = @meeting_type.meeting_type_agenda_sections.create!(title: "Post Business", position: 2)

    patch move_admin_meeting_type_agenda_section_path(@meeting_type, @section), params: { direction: "down" }

    assert_redirected_to edit_admin_meeting_type_path(@meeting_type)
    assert_equal "Agenda section moved.", flash[:notice]
    assert_equal [ second.id, @section.id ], @meeting_type.meeting_type_agenda_sections.ordered.ids
  end

  test "only an empty nonfinal section can be removed" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry = @organization.agenda_item_catalog_entries.create!(title: "Opening", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true)
    @meeting_type.meeting_type_agenda_items.create!(agenda_section: @section, agenda_item_catalog_entry: entry, title: "Opening", position: 1, active: true)

    delete admin_meeting_type_agenda_section_path(@meeting_type, @section)
    assert_equal "Move or remove this section's agenda items before removing the section.", flash[:alert]

    @meeting_type.meeting_type_agenda_items.destroy_all
    delete admin_meeting_type_agenda_section_path(@meeting_type, @section)
    assert_equal "A meeting type must keep at least one agenda section.", flash[:alert]

    second = @meeting_type.meeting_type_agenda_sections.create!(title: "Post Business", position: 2)
    assert_difference -> { @meeting_type.meeting_type_agenda_sections.count }, -1 do
      delete admin_meeting_type_agenda_section_path(@meeting_type, second)
    end
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
