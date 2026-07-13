require "test_helper"

class AgendaItemCatalogSeederTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
  end

  test "creates the lean regular meeting baseline" do
    assert_difference -> { @organization.agenda_item_catalog_entries.count }, 17 do
      AgendaItemCatalogSeeder.seed_for!(@organization)
    end

    titles = @organization.agenda_item_catalog_entries.order(:position).pluck(:title)
    assert_includes titles, "Opening Ceremony"
    assert_includes titles, "POW/MIA Empty Chair"
    assert_includes titles, "Unfinished / Old Business"
    assert_includes titles, "Good of The American Legion"
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

  test "can seed a second organization independently" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_difference -> { AgendaItemCatalogEntry.count }, 17 do
      AgendaItemCatalogSeeder.seed_for!(other)
    end
  end
end
