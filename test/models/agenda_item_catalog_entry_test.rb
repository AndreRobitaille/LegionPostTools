require "test_helper"

class AgendaItemCatalogEntryTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
  end

  test "validates category and behavior type" do
    entry = @organization.agenda_item_catalog_entries.new(
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      category: "not_a_category",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    assert_not entry.valid?
    assert_includes entry.errors[:category], "is not included in the list"
  end

  test "normalizes slug and enforces organization scoped uniqueness" do
    @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      slug: " Opening-Ceremony ",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    duplicate = @organization.agenda_item_catalog_entries.new(
      title: "Opening Ceremony Copy",
      slug: "opening-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 2,
      active: true
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "same slug can be reused by a different organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    entry = other_organization.agenda_item_catalog_entries.new(
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    assert entry.valid?
  end

  test "supports rich text body" do
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Preamble",
      slug: "preamble",
      category: "ceremony",
      behavior_type: "reading_recitation",
      position: 1,
      active: true,
      body: "For God and Country"
    )

    assert_includes entry.body.to_plain_text, "For God and Country"
  end
end
