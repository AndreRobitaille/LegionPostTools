require "test_helper"

class Admin::DatedAgendaSectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @agenda = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 9, 1, 19), title: "Membership Meeting", status: "draft")
    @section = @agenda.default_agenda_section
  end

  test "authorized officers can create rename and reorder sections" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    post admin_dated_agenda_agenda_sections_path(@agenda), params: { dated_agenda_section: { title: "Post Business" } }
    second = @agenda.dated_agenda_sections.find_by!(title: "Post Business")
    patch admin_dated_agenda_agenda_section_path(@agenda, second), params: { dated_agenda_section: { title: "New Business", lock_version: second.lock_version } }
    post reorder_admin_dated_agenda_agenda_sections_path(@agenda), params: { ids: [ second.id, @section.id ] }, as: :json

    assert_response :success
    assert_equal "New Business", second.reload.title
    assert_equal [ second.id, @section.id ], @agenda.dated_agenda_sections.ordered.ids
  end

  test "move changes the section order one position at a time" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    second = @agenda.dated_agenda_sections.create!(title: "Post Business", position: 2)

    patch move_admin_dated_agenda_agenda_section_path(@agenda, @section), params: { direction: "down" }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Agenda section moved.", flash[:notice]
    assert_equal [ second.id, @section.id ], @agenda.dated_agenda_sections.ordered.ids
  end

  test "locked agendas reject section pages and json reorder" do
    user = user_with_capabilities("manage_agendas")
    sign_in_as(user)
    @agenda.approve!(user)

    get new_admin_dated_agenda_agenda_section_path(@agenda)
    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before editing sections.", flash[:alert]

    post reorder_admin_dated_agenda_agenda_sections_path(@agenda), params: { ids: [ @section.id ] }, as: :json
    assert_response :locked

    patch move_admin_dated_agenda_agenda_section_path(@agenda, @section), params: { direction: "down" }
    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before editing sections.", flash[:alert]
  end

  test "cannot remove a nonempty section or the final section" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry = @organization.agenda_item_catalog_entries.create!(title: "Opening", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true)
    @agenda.dated_agenda_items.create!(agenda_section: @section, agenda_item_catalog_entry: entry, title: "Opening", behavior_type: "scripted_ceremony", position: 1, active: true)

    delete admin_dated_agenda_agenda_section_path(@agenda, @section)
    assert_equal "Move or remove this section's agenda items before removing the section.", flash[:alert]

    @agenda.dated_agenda_items.destroy_all
    delete admin_dated_agenda_agenda_section_path(@agenda, @section)
    assert_equal "An agenda must keep at least one section.", flash[:alert]
  end

  test "another organization's agenda is not found" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_body = other.meeting_bodies.create!(name: "Membership", slug: "membership")
    other_type = other.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    other_agenda = create_dated_agenda!(organization: other, meeting_body: other_body, meeting_type: other_type, starts_at: Time.zone.local(2026, 9, 1, 19), title: "Other", status: "draft")

    get edit_admin_dated_agenda_agenda_section_path(other_agenda, other_agenda.default_agenda_section)

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
