require "application_system_test_case"

class AgendaItemCatalogEntriesSystemTest < ApplicationSystemTestCase
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: person, email_address: "jane-catalog@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @user, capability: "manage_agendas")
    AgendaItemCatalogSeeder.seed_for!(@organization)
    system_sign_in(@user)
  end

  test "dragging a catalog item into another section saves its category and order" do
    source_entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.announcements")
    target_entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.introductions")
    visit admin_agenda_item_catalog_entries_path

    source = find("[data-reorder-id='#{source_entry.id}'] .pos-handle")
    target = find("[data-reorder-id='#{target_entry.id}']")
    source.drag_to(target, html5: true)

    assert_selector ".catalog-order-status", text: /saved/i
    assert_equal "membership", source_entry.reload.category
  end

  test "compact arrow controls move an item without JavaScript drag gestures" do
    entry = @organization.agenda_item_catalog_entries
      .where(category: "business")
      .order(:position)
      .second
    visit admin_agenda_item_catalog_entries_path

    within "[data-reorder-id='#{entry.id}']" do
      find("button[aria-label='Move #{entry.title} up']").click
    end

    assert_text "Agenda item moved."
    assert_equal entry.id, @organization.agenda_item_catalog_entries.where(category: "business").order(:position).first.id
  end
end
