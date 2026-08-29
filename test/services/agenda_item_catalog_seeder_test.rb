require "test_helper"

class AgendaItemCatalogSeederTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
  end

  test "creates the regular meeting baseline" do
    assert_difference -> { @organization.agenda_item_catalog_entries.count }, 28 do
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
    assert_equal "opening_ceremony", preamble.category
    assert_equal "reading_recitation", preamble.behavior_type
    assert_includes preamble.body.to_plain_text, "For God and Country"
    assert_includes preamble.body.to_plain_text, "mutual helpfulness"
    assert_predicate preamble, :show_wording_on_agenda?
    assert_not preamble.show_wording_in_minutes?

    opening = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_ceremony")
    assert_empty opening.body.to_plain_text
    assert_includes opening.commander_notes.to_plain_text, "three raps of the gavel"

    prayer = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_prayer")
    assert_not prayer.show_wording_on_agenda?
    assert_not prayer.show_wording_in_minutes?
  end

  test "creates every fresh entry with the declared catalog defaults" do
    AgendaItemCatalogSeeder.seed_for!(@organization)

    AgendaItemCatalogSeeder::ENTRIES.each do |definition|
      entry = @organization.agenda_item_catalog_entries.find_by!(source_key: definition.fetch(:source_key))

      %i[title slug summary category behavior_type position].each do |attribute|
        assert_equal definition.fetch(attribute), entry.public_send(attribute), "#{definition.fetch(:source_key)} #{attribute}"
      end
      assert_equal definition.fetch(:show_wording_on_agenda, true), entry.show_wording_on_agenda?, "#{definition.fetch(:source_key)} agenda wording"
      assert_equal definition.fetch(:show_wording_in_minutes, true), entry.show_wording_in_minutes?, "#{definition.fetch(:source_key)} minutes wording"
      assert_equal plain_text(definition.fetch(:body)), entry.body.to_plain_text.strip, "#{definition.fetch(:source_key)} body"
      assert_equal plain_text(definition.fetch(:commander_notes, "")), entry.commander_notes.to_plain_text.strip, "#{definition.fetch(:source_key)} commander notes"
    end

    assert_not @organization.agenda_item_catalog_entries.exists?(source_key: "regular_meeting.closing_ceremony")
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

  test "stores seeded bullet content as semantic lists" do
    AgendaItemCatalogSeeder.seed_for!(@organization)

    opening = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_ceremony")
    preamble = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.preamble")
    closing = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.closing_salute_colors")

    assert_equal 5, Nokogiri::HTML.fragment(opening.commander_notes.to_s).css("ul > li").count
    assert_equal 10, Nokogiri::HTML.fragment(preamble.body.to_s).css("ul > li").count
    assert_equal 4, Nokogiri::HTML.fragment(closing.commander_notes.to_s).css("ul > li").count
  end

  test "upgrades untouched literal bullets without overwriting local rich text" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    opening = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_ceremony")
    salute = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_salute_colors")
    legacy_notes = AgendaItemCatalogSeeder::ENTRIES.first.dig(:legacy, :commander_notes).last
    opening.update!(commander_notes: "<div>#{legacy_notes.gsub("\n", "<br>")}</div>")
    salute.update!(commander_notes: "Locally revised color guard instructions")
    assert_empty Nokogiri::HTML.fragment(opening.commander_notes.to_s).css("ul > li")

    AgendaItemCatalogSeeder.seed_for!(@organization)

    assert_equal 5, Nokogiri::HTML.fragment(opening.reload.commander_notes.to_s).css("ul > li").count
    assert_equal "Locally revised color guard instructions", salute.reload.commander_notes.to_plain_text
  end

  test "does not restore a seeded entry removed from the catalog" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_prayer")
    entry.remove_from_catalog!

    assert_no_difference -> { @organization.agenda_item_catalog_entries.count } do
      AgendaItemCatalogSeeder.seed_for!(@organization)
    end

    assert_predicate entry.reload.removed_from_catalog_at, :present?
    assert_not @organization.agenda_item_catalog_entries.kept.exists?(entry.id)
  end

  test "retires former section placeholders instead of recreating them as items" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Unfinished Business",
      summary: "Business carried over from earlier meetings.",
      category: "unfinished_business",
      behavior_type: "section_heading",
      position: 1,
      active: true,
      source_key: "regular_meeting.unfinished_old_business",
      source_label: AgendaItemCatalogSeeder::SOURCE_LABEL,
      seeded_at: Time.current
    )

    AgendaItemCatalogSeeder.seed_for!(@organization)

    assert_predicate entry.reload, :removed_from_catalog_at?
    assert_not @organization.agenda_item_catalog_entries.kept.exists?(source_key: "regular_meeting.unfinished_old_business")
    assert_not @organization.agenda_item_catalog_entries.kept.exists?(source_key: "regular_meeting.new_business_correspondence")
    assert @organization.agenda_item_catalog_entries.kept.exists?(source_key: "regular_meeting.closing_memorial_service")
    assert @organization.agenda_item_catalog_entries.kept.exists?(source_key: "regular_meeting.closing_service_reminder")
  end

  test "inserts newly introduced closing steps into an older catalog order" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.closing_memorial_service").destroy!
    @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.closing_service_reminder").destroy!
    %w[
      regular_meeting.pow_mia_flag_retrieval
      regular_meeting.closing_salute_colors
      regular_meeting.adjournment_declaration
    ].each_with_index do |source_key, index|
      @organization.agenda_item_catalog_entries.find_by!(source_key: source_key).update!(position: index + 1)
    end

    AgendaItemCatalogSeeder.seed_for!(@organization)

    assert_equal %w[
      regular_meeting.closing_memorial_service
      regular_meeting.closing_service_reminder
      regular_meeting.pow_mia_flag_retrieval
      regular_meeting.closing_salute_colors
      regular_meeting.adjournment_declaration
    ], @organization.agenda_item_catalog_entries.kept.where(category: "closing_ceremony").order(:position).pluck(:source_key)
  end

  test "can seed a second organization independently" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_difference -> { AgendaItemCatalogEntry.count }, 28 do
      AgendaItemCatalogSeeder.seed_for!(other)
    end
  end

  private

  def plain_text(content)
    ActionText::Content.new(content).to_plain_text.strip
  end
end
