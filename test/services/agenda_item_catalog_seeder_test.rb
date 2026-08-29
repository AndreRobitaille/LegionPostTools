require "test_helper"

class AgendaItemCatalogSeederTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
  end

  test "creates the regular meeting baseline" do
    assert_difference -> { @organization.agenda_item_catalog_entries.count }, 29 do
      AgendaItemCatalogSeeder.seed_for!(@organization)
    end

    entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_ceremony")
    assert_equal AgendaItemCatalogSeeder::SOURCE_LABEL, entry.source_label
    assert_predicate entry.seeded_at, :present?
    assert_equal true, entry.active
    assert_equal 1, entry.position

    roll_call = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.roll_call_quorum")
    assert_equal "roll_call", roll_call.behavior_type

    assert_no_difference -> { @organization.agenda_item_catalog_entries.count } do
      AgendaItemCatalogSeeder.seed_for!(@organization)
    end
  end

  test "upgrades the untouched roll call item to structured behavior" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.roll_call_quorum")
    entry.update_columns(behavior_type: "business_item")

    AgendaItemCatalogSeeder.seed_for!(@organization)

    assert_equal "roll_call", entry.reload.behavior_type
  end

  test "stores full script text for ceremony entries" do
    AgendaItemCatalogSeeder.seed_for!(@organization)

    preamble = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.preamble")
    assert_equal "ceremony", preamble.category
    assert_equal "reading_recitation", preamble.behavior_type
    assert_includes preamble.body.to_plain_text, "For God and Country"
    assert_includes preamble.body.to_plain_text, "mutual helpfulness"
  end

  test "does not overwrite local edits when run again" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_prayer")
    entry.update!(title: "Local Opening Prayer", body: "Locally edited prayer text")

    AgendaItemCatalogSeeder.seed_for!(@organization)

    entry.reload
    assert_equal "Local Opening Prayer", entry.title
    assert_equal "Locally edited prayer text", entry.body.to_plain_text.strip
  end

  test "upgrades untouched officer-facing wording from the earlier baseline" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.unfinished_old_business")
    entry.update_columns(
      title: "Unfinished / Old Business",
      summary: "Business carried over from earlier meetings."
    )
    entry.body.update!(body: "Bring forward business postponed from previous meetings or matters introduced earlier where action was not completed.")

    AgendaItemCatalogSeeder.seed_for!(@organization)

    entry.reload
    assert_equal "Unfinished Business", entry.title
    assert_equal "A specific motion, proposal, or decision left unresolved from an earlier meeting.", entry.summary
    assert_includes entry.body.to_plain_text, "membership still owes a decision"
    assert_not_includes entry.title, "Old Business"
  end

  test "can seed a second organization independently" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_difference -> { AgendaItemCatalogEntry.count }, 29 do
      AgendaItemCatalogSeeder.seed_for!(other)
    end
  end
end
