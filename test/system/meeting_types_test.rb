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

  test "drag-reordering agenda items auto-saves the new order" do
    pec = pec_meeting
    visit edit_admin_meeting_type_path(pec)

    items = pec.meeting_type_agenda_items.ordered.to_a
    original_first = items.first
    original_last = items.last

    source = find("[data-reorder-id='#{original_first.id}'] .pos-handle")
    target = find("[data-reorder-id='#{original_last.id}']")
    source.drag_to(target, html5: true)

    assert_selector ".pos-status", text: /saved/i
    assert_not_equal original_first.id,
      pec.meeting_type_agenda_items.ordered.first.id,
      "the first item should no longer be first after dragging it down"
  end
end
