require "test_helper"

class MeetingTypeTemplateSeederTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    AgendaItemCatalogSeeder.seed_for!(@organization)
  end

  test "seeds default meeting types for an unseeded organization" do
    organization = Organization.create!(name: "Fresh Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_difference -> { organization.agenda_item_catalog_entries.count }, 29 do
      assert_difference -> { organization.meeting_types.count }, 2 do
        MeetingTypeTemplateSeeder.seed_for!(organization)
      end
    end

    assert_equal [ "PEC Meeting", "Membership Meeting" ], organization.meeting_types.ordered.pluck(:name)
    assert_equal 29, organization.agenda_item_catalog_entries.count
    assert_equal 2, organization.meeting_types.count
    assert organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting").seeded?
    assert organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting").seeded?
  end

  test "seeds membership meeting with exact ordered titles" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    titles = membership.meeting_type_agenda_items.ordered.pluck(:title)

    assert_equal [
      "Hand Salute / Colors",
      "Chaplain's Prayer",
      "POW/MIA Empty Chair",
      "Pledge of Allegiance",
      "American Legion Preamble",
      "Declare the Post in Session",
      "Roll Call and Quorum",
      "Approval of Minutes",
      "Guests and New Members",
      "Finance Officer Report",
      "Adjutant Report",
      "Commander Report",
      "Historian Report",
      "Chaplain / Honor Guard Report",
      "Programs & Activities",
      "Sick Call",
      "Service Officer Report",
      "Unfinished Business",
      "New Business",
      "Good of The American Legion",
      "Announcements",
      "Retrieve the POW/MIA Flag",
      "Hand Salute / Colors",
      "Declare the Meeting Adjourned"
    ], titles
  end

  test "seeds pec meeting with exact ordered titles" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    titles = pec.meeting_type_agenda_items.ordered.pluck(:title)

    assert_equal [
      "Roll Call and Quorum",
      "Approval of Minutes",
      "Unfinished Business",
      "New Business",
      "Good of The American Legion"
    ], titles
  end

  test "seeds meeting-shaped sections for the supplied templates" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")

    assert_equal [ "Call to Order", "Post Business" ], pec.meeting_type_agenda_sections.ordered.pluck(:title)
    assert_equal [
      "Opening Ceremony",
      "Roll Call, Minutes & Guests",
      "Reports",
      "Sick Call / Service Officer",
      "Unfinished Business",
      "New Business",
      "Good of The American Legion & Announcements",
      "Closing Ceremony & Adjournment"
    ], membership.meeting_type_agenda_sections.ordered.pluck(:title)
    assert_equal [ 2, 3 ], pec.meeting_type_agenda_sections.ordered.map { |section| section.agenda_items.count }
    assert_equal [ 6, 3, 6, 2, 1, 1, 2, 3 ], membership.meeting_type_agenda_sections.ordered.map { |section| section.agenda_items.count }
  end

  test "reseeding does not overwrite local edits" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    item = membership.meeting_type_agenda_items.ordered.first

    membership.update!(name: "Local Membership Meeting", active: false)
    item.update!(title: "Local Template Item", summary: "Local summary", body: "Local body", position: 99, active: false)

    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_equal "Local Membership Meeting", membership.reload.name
    assert_not membership.active?
    assert_equal "Local Template Item", item.reload.title
    assert_equal "Local summary", item.summary
    assert_equal "Local body", item.body.to_plain_text
    assert_equal 99, item.position
    assert_not item.active?
  end

  test "reseeding does not reactivate a removed seeded template item" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    item = membership.meeting_type_agenda_items.find_by!(source_key: "american_legion_post:membership_meeting:regular_meeting.opening_salute_colors")

    item.update!(active: false)

    assert_no_difference -> { membership.meeting_type_agenda_items.count } do
      MeetingTypeTemplateSeeder.seed_for!(@organization)
    end

    assert_not item.reload.active?
  end

  test "reseeding does not change meeting type or template item counts" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_no_difference -> { @organization.meeting_types.count } do
      assert_no_difference -> { @organization.meeting_types.sum { |meeting_type| meeting_type.meeting_type_agenda_items.count } } do
        MeetingTypeTemplateSeeder.seed_for!(@organization)
      end
    end
  end

  test "template reset does not restore a removed catalog entry" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    catalog_entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_salute_colors")
    template_source_key = "american_legion_post:membership_meeting:regular_meeting.opening_salute_colors"
    assert membership.meeting_type_agenda_items.exists?(source_key: template_source_key)

    catalog_entry.remove_from_catalog!
    MeetingTypeTemplateSeeder.reset_agenda_for!(membership)

    assert_not membership.meeting_type_agenda_items.exists?(source_key: template_source_key)
    assert_not MeetingTypeTemplateSeeder.defaults_missing?(@organization)
  end

  test "reseeding upgrades existing seeded items from the migration fallback section" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    fallback = membership.meeting_type_agenda_sections.create!(title: "Order of Business", position: 9)

    membership.meeting_type_agenda_items.ordered.each_with_index do |item, index|
      item.update!(agenda_section: fallback, position: index + 1)
    end
    membership.meeting_type_agenda_sections.where.not(id: fallback.id).destroy_all
    fallback.update!(position: 1)

    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_equal [
      "Opening Ceremony",
      "Roll Call, Minutes & Guests",
      "Reports",
      "Sick Call / Service Officer",
      "Unfinished Business",
      "New Business",
      "Good of The American Legion & Announcements",
      "Closing Ceremony & Adjournment"
    ],
      membership.meeting_type_agenda_sections.ordered.pluck(:title)
    assert_equal [ 6, 3, 6, 2, 1, 1, 2, 3 ],
      membership.meeting_type_agenda_sections.ordered.map { |section| section.agenda_items.count }
  end

  test "seeding is independent by organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    AgendaItemCatalogSeeder.seed_for!(other_organization)

    MeetingTypeTemplateSeeder.seed_for!(@organization)
    MeetingTypeTemplateSeeder.seed_for!(other_organization)

    assert_equal 2, @organization.meeting_types.count
    assert_equal 2, other_organization.meeting_types.count
  end

  test "defaults_missing? is true when a seeded meeting type is missing template items" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    membership.meeting_type_agenda_items.first.destroy!

    assert MeetingTypeTemplateSeeder.defaults_missing?(@organization)
  end

  test "seeding appends defaults when preferred positions are taken by custom meeting types" do
    @organization.meeting_types.create!(name: "Custom Meeting", position: 1, active: true)

    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_equal [ "Custom Meeting", "PEC Meeting", "Membership Meeting" ], @organization.meeting_types.ordered.pluck(:name)
    assert_equal [ 1, 2, 3 ], @organization.meeting_types.ordered.pluck(:position)
  end

  test "reseeding a missing template item appends when its canonical position is occupied locally" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    seeded_item = membership.meeting_type_agenda_items.find_by!(source_key: "american_legion_post:membership_meeting:regular_meeting.opening_salute_colors")
    canonical_position = seeded_item.position

    seeded_item.destroy!
    local_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Local Opening",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 99,
      active: true
    )
    membership.meeting_type_agenda_items.create!(agenda_item_catalog_entry: local_entry, position: canonical_position, title: "Local Opening", active: true)

    assert_difference -> { membership.meeting_type_agenda_items.count }, 1 do
      MeetingTypeTemplateSeeder.seed_for!(@organization)
    end

    reseeded_item = membership.meeting_type_agenda_items.find_by!(source_key: "american_legion_post:membership_meeting:regular_meeting.opening_salute_colors")
    assert_not_equal canonical_position, reseeded_item.position
    membership.meeting_type_agenda_sections.each do |section|
      positions = section.agenda_items.pluck(:position)
      assert_equal positions.uniq.sort, positions.sort
    end
  end

  test "reset_for! restores suggested meeting types to defaults and leaves custom types" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    custom = @organization.meeting_types.create!(name: "Custom Meeting", position: 9, active: true)
    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    pec.meeting_type_agenda_items.first.destroy
    pec.update!(name: "Renamed PEC")

    MeetingTypeTemplateSeeder.reset_for!(@organization)

    assert @organization.meeting_types.exists?(custom.id), "custom types must survive reset"
    restored = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    assert_equal "PEC Meeting", restored.name
    assert_equal 5, restored.meeting_type_agenda_items.count
  end

  test "reset_agenda_for! restores one suggested type's items to default" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    pec.meeting_type_agenda_items.destroy_all

    assert MeetingTypeTemplateSeeder.reset_agenda_for!(pec)
    assert_equal 5, pec.reload.meeting_type_agenda_items.count
    assert_equal [ "Call to Order", "Post Business" ], pec.meeting_type_agenda_sections.ordered.pluck(:title)
    assert_equal [ [ 1, 2 ], [ 1, 2, 3 ] ], pec.meeting_type_agenda_sections.ordered.map { |section| section.agenda_items.pluck(:position) }
  end

  test "reset_agenda_for! is a no-op for a non-suggested meeting type" do
    custom = @organization.meeting_types.create!(name: "Custom Meeting", position: 1, active: true)

    assert_not MeetingTypeTemplateSeeder.reset_agenda_for!(custom)
  end
end
