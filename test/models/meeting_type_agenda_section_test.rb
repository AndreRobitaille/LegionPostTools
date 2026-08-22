require "test_helper"

class MeetingTypeAgendaSectionTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
  end

  test "new meeting types receive a default section" do
    assert_equal [ "Order of Business" ], @meeting_type.meeting_type_agenda_sections.pluck(:title)
    assert_equal [ 1 ], @meeting_type.meeting_type_agenda_sections.pluck(:position)
  end

  test "section titles are normalized and unique within a meeting type" do
    @meeting_type.default_agenda_section.update!(title: "  Opening Ceremony  ")
    duplicate = @meeting_type.meeting_type_agenda_sections.new(title: "Opening Ceremony", position: 2)

    assert_equal "Opening Ceremony", @meeting_type.default_agenda_section.reload.title
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:title], "has already been taken"
  end

  test "reorder changes only the selected meeting type" do
    first = @meeting_type.default_agenda_section
    second = @meeting_type.meeting_type_agenda_sections.create!(title: "Post Business", position: 2)
    other_type = @organization.meeting_types.create!(name: "PEC Meeting", position: 2, active: true)

    MeetingTypeAgendaSection.reorder!(@meeting_type, [ second.id, first.id ])

    assert_equal [ "Post Business", "Order of Business" ], @meeting_type.meeting_type_agenda_sections.ordered.pluck(:title)
    assert_equal [ "Order of Business" ], other_type.meeting_type_agenda_sections.pluck(:title)
  end

  test "a section with agenda items cannot be destroyed directly" do
    section = @meeting_type.default_agenda_section
    entry = @organization.agenda_item_catalog_entries.create!(title: "Opening", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true)
    @meeting_type.meeting_type_agenda_items.create!(agenda_section: section, agenda_item_catalog_entry: entry, title: "Opening", position: 1, active: true)

    assert_not section.destroy
    assert MeetingTypeAgendaSection.exists?(section.id)
  end
end
