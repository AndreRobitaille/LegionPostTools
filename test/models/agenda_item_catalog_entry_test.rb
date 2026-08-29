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
      behavior_type: "not_a_behavior_type",
      position: 1,
      active: true
    )

    assert_not entry.valid?
    assert_includes entry.errors[:category], "is not included in the list"
    assert_includes entry.errors[:behavior_type], "is not included in the list"
  end

  test "normalizes blank source keys to nil and allows duplicates" do
    first = @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true,
      source_key: ""
    )

    second = @organization.agenda_item_catalog_entries.create!(
      title: "Closing Ceremony",
      slug: "closing-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 2,
      active: true,
      source_key: nil
    )

    assert_nil first.source_key
    assert_nil second.source_key
  end

  test "normalizes nil summary to an empty string" do
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true,
      summary: nil
    )

    assert_equal "", entry.summary
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

  test "derives slug from title when none is given" do
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    assert_equal "opening-ceremony", entry.slug
  end

  test "derived slug avoids collisions within the organization" do
    @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    second = @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 2,
      active: true
    )

    assert_equal "opening-ceremony-2", second.slug
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

  test "defaults document wording to the agenda and draft minutes" do
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Call to Order",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    assert entry.show_wording_on_agenda?
    assert entry.show_wording_in_minutes?
  end

  test "supports private Commander notes" do
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Call to Order",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true,
      commander_notes: "Give three raps of the gavel."
    )

    assert_includes entry.commander_notes.to_plain_text, "three raps"
  end

  test "reorder changes categories and writes contiguous positions" do
    ceremony = create_entry("Ceremony", "ceremony", 8)
    business_first = create_entry("First Business", "business", 4)
    business_second = create_entry("Second Business", "business", 9)

    AgendaItemCatalogEntry.reorder!(@organization, {
      "ceremony" => [ ceremony.id, business_second.id ],
      "business" => [ business_first.id ]
    })

    assert_equal [ [ "ceremony", 1 ], [ "ceremony", 2 ], [ "business", 1 ] ],
      [ ceremony, business_second, business_first ].map { |entry| entry.reload.slice(:category, :position).values }
  end

  test "reorder rejects incomplete duplicate and unknown category payloads atomically" do
    first = create_entry("First", "ceremony", 3)
    second = create_entry("Second", "business", 7)
    original = [ first, second ].map { |entry| entry.slice(:category, :position) }

    invalid_orders = [
      { "ceremony" => [ first.id ] },
      { "ceremony" => [ first.id, first.id ] },
      { "ceremony" => [ first.id ], "unknown" => [ second.id ] }
    ]

    invalid_orders.each do |order|
      assert_raises(ActiveRecord::RecordNotFound) do
        AgendaItemCatalogEntry.reorder!(@organization, order)
      end
      assert_equal original, [ first.reload, second.reload ].map { |entry| entry.slice(:category, :position) }
    end
  end

  test "reorder rejects an entry from another post" do
    entry = create_entry("Post Item", "ceremony", 1)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.agenda_item_catalog_entries.create!(
      title: "Foreign", category: "business", behavior_type: "business_item", position: 1, active: true
    )

    assert_raises(ActiveRecord::RecordNotFound) do
      AgendaItemCatalogEntry.reorder!(@organization, "ceremony" => [ entry.id, foreign.id ])
    end

    assert_equal [ "ceremony", 1 ], entry.reload.slice(:category, :position).values
  end

  test "move reorders within a category and crosses the adjacent category boundary" do
    first = create_entry("First", "ceremony", 1)
    second = create_entry("Second", "ceremony", 2)

    AgendaItemCatalogEntry.move!(@organization, second, "up")

    assert_equal [ second.id, first.id ], entries_in("ceremony").map(&:id)

    AgendaItemCatalogEntry.move!(@organization, first, "down")

    assert_equal [ second.id ], entries_in("ceremony").map(&:id)
    assert_equal [ first.id ], entries_in("business").map(&:id)
  end

  test "move rejects the outer catalog boundaries" do
    first = create_entry("First", "ceremony", 1)
    last = create_entry("Last", "administration", 1)

    assert_raises(ActiveRecord::RecordNotFound) { AgendaItemCatalogEntry.move!(@organization, first, "up") }
    assert_raises(ActiveRecord::RecordNotFound) { AgendaItemCatalogEntry.move!(@organization, last, "down") }
  end

  test "removing an entry preserves template and dated agenda copies" do
    first = create_entry("First", "ceremony", 1)
    removed = create_entry("Removable", "ceremony", 2)
    last = create_entry("Last", "ceremony", 3)
    meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    template_item = MeetingTypeAgendaItem.create_from_catalog_entry!(removed, position: 1, meeting_type: meeting_type)
    meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    dated_agenda = DatedAgenda.create_from_template!(
      organization: @organization,
      meeting_body: meeting_body,
      meeting_type: meeting_type,
      starts_at: Time.zone.local(2026, 8, 29, 19, 0)
    )
    dated_item = dated_agenda.dated_agenda_items.find_by!(agenda_item_catalog_entry: removed)

    assert_no_difference -> { AgendaItemCatalogEntry.count } do
      removed.remove_from_catalog!
    end

    assert_predicate removed, :removed_from_catalog_at?
    assert_not_includes @organization.agenda_item_catalog_entries.kept, removed
    assert_not_includes @organization.agenda_item_catalog_entries.active, removed
    assert_equal [ [ first.id, 1 ], [ last.id, 2 ] ], entries_in("ceremony").kept.pluck(:id, :position)
    assert_equal removed, template_item.reload.agenda_item_catalog_entry
    assert_equal removed, dated_item.reload.agenda_item_catalog_entry
  end

  private

  def create_entry(title, category, position)
    @organization.agenda_item_catalog_entries.create!(
      title: title,
      category: category,
      behavior_type: "business_item",
      position: position,
      active: true
    )
  end

  def entries_in(category)
    @organization.agenda_item_catalog_entries.where(category: category).order(:position)
  end
end
