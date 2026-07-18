require "test_helper"

class MeetingTypeAgendaItemTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      summary: "Open the meeting",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true,
      body: "<strong>Original</strong> opening wording"
    )
  end

  test "copies title summary and body from catalog entry" do
    item = @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)

    assert_equal "Opening Ceremony", item.title
    assert_equal "Open the meeting", item.summary
    assert_equal "Original opening wording", item.body.to_plain_text.strip
    assert_includes item.body.to_s, "<strong>Original</strong>"
  end

  test "template edits do not modify the catalog entry" do
    item = @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)

    item.update!(title: "Local Opening", summary: "Local summary", body: "Local wording")

    assert_equal "Opening Ceremony", @catalog_entry.reload.title
    assert_equal "Open the meeting", @catalog_entry.summary
    assert_equal "Original opening wording", @catalog_entry.body.to_plain_text.strip
    assert_includes @catalog_entry.body.to_s, "<strong>Original</strong>"
  end

  test "prevents duplicate catalog entry in same meeting type" do
    @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)
    duplicate = @meeting_type.meeting_type_agenda_items.new(agenda_item_catalog_entry: @catalog_entry, position: 2, title: "Duplicate", active: true)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:agenda_item_catalog_entry_id], "has already been taken"
  end

  test "position uniqueness is scoped to meeting type" do
    @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)
    second_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Second Entry",
      category: "business",
      behavior_type: "business_item",
      position: 2,
      active: true
    )

    duplicate = @meeting_type.meeting_type_agenda_items.new(
      agenda_item_catalog_entry: second_entry,
      position: 1,
      title: "Second Entry",
      active: true
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:position], "has already been taken"
  end

  test "same catalog entry can be used by another meeting type in same organization" do
    other_meeting_type = @organization.meeting_types.create!(name: "PEC Meeting", position: 2, active: true)
    @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)

    item = other_meeting_type.meeting_type_agenda_items.new(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Opening", active: true)

    assert item.valid?
  end

  test "rejects catalog entries from another organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_entry = other_organization.agenda_item_catalog_entries.create!(
      title: "Other Entry",
      category: "business",
      behavior_type: "business_item",
      position: 1,
      active: true
    )

    item = @meeting_type.meeting_type_agenda_items.new(agenda_item_catalog_entry: other_entry, position: 1, title: "Bad", active: true)

    assert_not item.valid?
    assert_includes item.errors[:agenda_item_catalog_entry], "must belong to the same organization"
  end
end
