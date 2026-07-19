require "application_system_test_case"

# Browser-driven coverage for the dated-agenda management screen: the Stimulus /
# SortableJS drag reorder and the locked-state hiding of edit controls that
# request tests can't exercise.
class DatedAgendasSystemTest < ApplicationSystemTestCase
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @user, capability: "manage_agendas")

    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    opening = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", slug: "opening-ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true, body: "Opening")
    report = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", slug: "commander-report", category: "reports", behavior_type: "report_slot", position: 2, active: true, body: "Report")
    @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: opening, position: 1, title: "Opening Ceremony", active: true, body: "Opening")
    @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: report, position: 2, title: "Commander Report", active: true, body: "Report")
    @agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    system_sign_in(@user)
  end

  test "drag-reordering agenda items auto-saves the new order" do
    visit edit_admin_dated_agenda_path(@agenda)

    items = @agenda.dated_agenda_items.ordered.to_a
    first = items.first
    last = items.last

    source = find("[data-reorder-id='#{first.id}'] .pos-handle")
    target = find("[data-reorder-id='#{last.id}']")
    source.drag_to(target, html5: true)

    assert_selector ".pos-status", text: /saved/i
    assert_not_equal first.id,
      @agenda.dated_agenda_items.ordered.first.id,
      "the first item should no longer be first after dragging it down"
  end

  test "approved agenda hides drag handles and item edit controls" do
    @agenda.approve!(@user)
    visit edit_admin_dated_agenda_path(@agenda)

    assert_selector ".da-lifecycle .st.st--approved"
    assert_selector ".readonly-tip"
    assert_no_selector ".pos-handle"
    assert_no_selector "button.row-del"
  end
end
