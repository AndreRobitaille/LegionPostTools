require "application_system_test_case"

# Browser-driven coverage for the Meeting Types admin refresh: the Stimulus /
# Turbo / SortableJS behaviour that request tests can't reach (inline rename,
# instant toggle, confirm-and-delete, drag reorder).
class MeetingTypesSystemTest < ApplicationSystemTestCase
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @user, capability: "manage_agendas")
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    system_sign_in(@user)
  end

  def pec_meeting
    @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
  end

  test "renaming a meeting type via click-to-edit" do
    pec = pec_meeting
    visit edit_admin_meeting_type_path(pec)

    assert_selector "h1.page-title", text: "PEC Meeting"
    click_button "Rename"
    fill_in "meeting_type[name]", with: "Executive Committee"
    click_button "Save"

    assert_selector "h1.page-title", text: "Executive Committee"
    assert_equal "Executive Committee", pec.reload.name
  end

  test "toggling active state without a form submit button" do
    pec = pec_meeting
    visit edit_admin_meeting_type_path(pec)

    assert_selector ".mt-active .state.on", text: "Active"
    click_button "Deactivate"

    assert_selector ".mt-active .state.off", text: "Inactive"
    assert_not pec.reload.active?
  end

  test "deleting a meeting type after confirming" do
    custom = @organization.meeting_types.create!(name: "Special Ceremony", position: 99, active: true)
    visit admin_meeting_types_path

    assert_selector ".mrow-name", text: "Special Ceremony"
    accept_confirm do
      within "[data-reorder-id='#{custom.id}']" do
        find("button.row-del").click
      end
    end

    assert_no_selector ".mrow-name", text: "Special Ceremony"
    assert_not MeetingType.exists?(custom.id)
  end

  test "removing a template item after confirming preserves a published agenda" do
    pec = pec_meeting
    item = pec.meeting_type_agenda_items.ordered.first
    meeting_body = @organization.meeting_bodies.create!(name: "Executive Committee", slug: "executive-committee")
    agenda = create_dated_agenda_from_template!(
      organization: @organization,
      meeting_body: meeting_body,
      meeting_type: pec,
      starts_at: Time.zone.local(2026, 10, 6, 19, 0)
    )
    copied_item = agenda.dated_agenda_items.find_by!(meeting_type_agenda_item: item)
    original_title = copied_item.title
    agenda.approve!(@user)
    agenda.publish!(@user)
    visit edit_admin_meeting_type_path(pec)

    accept_confirm do
      within ".agenda-item-row[data-reorder-id='#{item.id}']" do
        find("button.row-del").click
      end
    end

    assert_text "Item removed from the agenda."
    assert_no_selector ".agenda-item-row[data-reorder-id='#{item.id}']"
    assert_not MeetingTypeAgendaItem.exists?(item.id)
    assert_nil copied_item.reload.meeting_type_agenda_item_id
    assert_equal original_title, copied_item.title
    assert_predicate agenda.reload, :published?
  end

  test "drag-reordering agenda items auto-saves the new order" do
    pec = pec_meeting
    visit edit_admin_meeting_type_path(pec)

    section = pec.meeting_type_agenda_sections.find_by!(title: "Call to Order")
    items = section.agenda_items.to_a
    original_first = items.first
    original_last = items.last

    source = find(".agenda-section[data-reorder-id='#{section.id}'] .agenda-item-row[data-reorder-id='#{original_first.id}'] .pos-handle")
    target = find(".agenda-section[data-reorder-id='#{section.id}'] .agenda-item-row[data-reorder-id='#{original_last.id}']")
    source.drag_to(target, html5: true)

    assert_selector ".pos-status", text: /saved/i
    assert_not_equal original_first.id,
      section.agenda_items.reload.first.id,
      "the first item should no longer be first after dragging it down"
  end

  test "moving agenda sections saves the meeting order" do
    pec = pec_meeting
    visit edit_admin_meeting_type_path(pec)

    sections = pec.meeting_type_agenda_sections.ordered.to_a
    original_first = sections.first

    within ".agenda-section[data-reorder-id='#{original_first.id}']" do
      click_button "Move down"
    end

    assert_text "Agenda section moved."
    assert_not_equal original_first.id, pec.meeting_type_agenda_sections.ordered.first.id
  end
end
