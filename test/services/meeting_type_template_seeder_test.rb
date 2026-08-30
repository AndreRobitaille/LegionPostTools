require "test_helper"

class MeetingTypeTemplateSeederTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    AgendaItemCatalogSeeder.seed_for!(@organization)
  end

  test "seeds default meeting types for an unseeded organization" do
    organization = Organization.create!(name: "Fresh Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_difference -> { organization.agenda_item_catalog_entries.count }, 28 do
      assert_difference -> { organization.meeting_types.count }, 2 do
        MeetingTypeTemplateSeeder.seed_for!(organization)
      end
    end

    assert_equal [ "PEC Meeting", "Membership Meeting" ], organization.meeting_types.ordered.pluck(:name)
    assert_equal 28, organization.agenda_item_catalog_entries.count
    assert_equal 2, organization.meeting_types.count
    assert organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting").seeded?
    assert organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting").seeded?
  end

  test "seeds membership meeting with exact ordered titles" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    titles = membership.meeting_type_agenda_items.ordered.pluck(:title)

    assert_equal [
      "Call the Meeting to Order",
      "Colors & Hand Salute",
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
      "Good of The American Legion",
      "Announcements",
      "Closing Memorial Service",
      "Service and Citizenship Reminder",
      "Retrieve the POW/MIA Flag",
      "Hand Salute & Retire Colors",
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
      "Good of The American Legion"
    ], titles
  end

  test "seeds meeting-shaped sections for the supplied templates" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")

    assert_equal [ "Call to Order", "Unfinished Business", "New Business", "Good of The American Legion" ],
      pec.meeting_type_agenda_sections.ordered.pluck(:title)
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
    assert_equal [ 2, 0, 0, 1 ], pec.meeting_type_agenda_sections.ordered.map { |section| section.agenda_items.count }
    assert_equal [ 7, 3, 6, 2, 0, 0, 2, 5 ], membership.meeting_type_agenda_sections.ordered.map { |section| section.agenda_items.count }
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

  test "reseeding upgrades untouched literal bullets in template items" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    opening = membership.meeting_type_agenda_items.find_by!(source_key: "american_legion_post:membership_meeting:regular_meeting.opening_ceremony")
    legacy_notes = AgendaItemCatalogSeeder::ENTRIES.first.dig(:legacy, :commander_notes).last
    opening.update!(commander_notes: "<div>#{legacy_notes.gsub("\n", "<br>")}</div>")
    assert_empty Nokogiri::HTML.fragment(opening.commander_notes.to_s).css("ul > li")

    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_equal 5, Nokogiri::HTML.fragment(opening.reload.commander_notes.to_s).css("ul > li").count
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

  test "retires a referenced placeholder without changing its dated agenda snapshot" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    post_business = pec.meeting_type_agenda_sections.find_by!(title: "Unfinished Business")
    new_business = pec.meeting_type_agenda_sections.find_by!(title: "New Business")
    good_section = pec.meeting_type_agenda_sections.find_by!(title: "Good of The American Legion")
    good_item = good_section.agenda_items.find_by!(source_key: "american_legion_post:pec_meeting:regular_meeting.good_of_legion")
    good_item.update!(agenda_section: post_business, position: 2)
    new_business.destroy!
    good_section.destroy!
    post_business.update!(title: "Post Business")
    catalog_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Unfinished Business",
      category: "unfinished_business",
      behavior_type: "section_heading",
      position: 1,
      active: true,
      source_key: "regular_meeting.unfinished_old_business",
      source_label: AgendaItemCatalogSeeder::SOURCE_LABEL,
      seeded_at: Time.current
    )
    template_item = MeetingTypeAgendaItem.create_from_catalog_entry!(
      catalog_entry,
      position: 1,
      meeting_type: pec,
      agenda_section: post_business
    )
    template_item.update!(
      source_key: "american_legion_post:pec_meeting:regular_meeting.unfinished_old_business",
      source_label: MeetingTypeTemplateSeeder::SOURCE_LABEL,
      seeded_at: Time.current
    )
    meeting_body = @organization.meeting_bodies.create!(name: "Post Executive Committee", slug: "pec")
    dated_agenda = create_dated_agenda_from_template!(
      organization: @organization,
      meeting_body: meeting_body,
      meeting_type: pec,
      starts_at: Time.zone.local(2026, 9, 1, 18, 0)
    )
    snapshot = dated_agenda.dated_agenda_items.find_by!(meeting_type_agenda_item: template_item)

    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_not template_item.reload.active?
    assert_equal "Unfinished Business", template_item.agenda_section.title
    assert_not pec.meeting_type_agenda_sections.exists?(title: "Post Business")
    assert_equal "Unfinished Business", snapshot.reload.title
    assert dated_agenda.dated_agenda_sections.exists?(title: "Post Business")
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
    assert_equal [ 7, 3, 6, 2, 0, 0, 2, 5 ],
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
      category: "opening_ceremony",
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

  test "inserts newly introduced ceremony items into an older template order" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    opening = membership.meeting_type_agenda_sections.find_by!(title: "Opening Ceremony")
    closing = membership.meeting_type_agenda_sections.find_by!(title: "Closing Ceremony & Adjournment")
    membership.meeting_type_agenda_items.where(source_key: [
      "american_legion_post:membership_meeting:regular_meeting.opening_ceremony",
      "american_legion_post:membership_meeting:regular_meeting.closing_memorial_service",
      "american_legion_post:membership_meeting:regular_meeting.closing_service_reminder"
    ]).destroy_all
    [ opening, closing ].each do |section|
      section.agenda_items.order(:position).each_with_index do |item, index|
        item.update!(position: index + 1)
      end
    end

    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_equal %w[
      regular_meeting.opening_ceremony
      regular_meeting.opening_salute_colors
      regular_meeting.opening_prayer
      regular_meeting.pow_mia_empty_chair
      regular_meeting.pledge_of_allegiance
      regular_meeting.preamble
      regular_meeting.opening_declaration
    ], opening.agenda_items.order(:position).pluck(:source_key).map { |source_key| source_key.split(":").last }
    assert_equal %w[
      regular_meeting.closing_memorial_service
      regular_meeting.closing_service_reminder
      regular_meeting.pow_mia_flag_retrieval
      regular_meeting.closing_salute_colors
      regular_meeting.adjournment_declaration
    ], closing.agenda_items.order(:position).pluck(:source_key).map { |source_key| source_key.split(":").last }
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
    assert_equal 3, restored.meeting_type_agenda_items.count
  end

  test "reset_agenda_for! restores one suggested type's items to default" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    pec.meeting_type_agenda_items.destroy_all

    assert MeetingTypeTemplateSeeder.reset_agenda_for!(pec)
    assert_equal 3, pec.reload.meeting_type_agenda_items.count
    assert_equal [ "Call to Order", "Unfinished Business", "New Business", "Good of The American Legion" ],
      pec.meeting_type_agenda_sections.ordered.pluck(:title)
    assert_equal [ [ 1, 2 ], [], [], [ 1 ] ],
      pec.meeting_type_agenda_sections.ordered.map { |section| section.agenda_items.pluck(:position) }
  end

  test "reset_agenda_for! is a no-op for a non-suggested meeting type" do
    custom = @organization.meeting_types.create!(name: "Custom Meeting", position: 1, active: true)

    assert_not MeetingTypeTemplateSeeder.reset_agenda_for!(custom)
  end
end
