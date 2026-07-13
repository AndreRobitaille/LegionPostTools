class MeetingTypeTemplateSeeder
  SOURCE_LABEL = "American Legion meeting type template seed".freeze

  MEETING_TYPES = [
    {
      name: "PEC Meeting",
      source_key: "american_legion_post:pec_meeting",
      position: 1,
      item_source_keys: [
        "regular_meeting.roll_call_quorum",
        "regular_meeting.previous_minutes",
        "regular_meeting.unfinished_old_business",
        "regular_meeting.new_business_correspondence",
        "regular_meeting.good_of_legion"
      ]
    },
    {
      name: "Membership Meeting",
      source_key: "american_legion_post:membership_meeting",
      position: 2,
      item_source_keys: [
        "regular_meeting.opening_ceremony",
        "regular_meeting.opening_prayer",
        "regular_meeting.pow_mia_empty_chair",
        "regular_meeting.pledge_of_allegiance",
        "regular_meeting.preamble",
        "regular_meeting.roll_call_quorum",
        "regular_meeting.previous_minutes",
        "regular_meeting.introductions",
        "regular_meeting.committee_reports",
        "regular_meeting.balloting_on_applications",
        "regular_meeting.sick_call_relief_employment",
        "regular_meeting.service_officer_report",
        "regular_meeting.unfinished_old_business",
        "regular_meeting.new_business_correspondence",
        "regular_meeting.memorial_departed_member",
        "regular_meeting.good_of_legion",
        "regular_meeting.closing_ceremony"
      ]
    }
  ].freeze

  def self.seed_for!(organization)
    new(organization).seed!
  end

  def initialize(organization)
    @organization = organization
  end

  def seed!
    AgendaItemCatalogSeeder.seed_for!(organization)

    ApplicationRecord.transaction do
      MEETING_TYPES.each { |definition| seed_meeting_type(definition) }
    end
  end

  private

  attr_reader :organization

  def seed_meeting_type(definition)
    meeting_type = organization.meeting_types.find_or_initialize_by(source_key: definition.fetch(:source_key))
    if meeting_type.new_record?
      meeting_type.name = definition.fetch(:name)
      meeting_type.position = definition.fetch(:position)
      meeting_type.active = true
      meeting_type.source_label = SOURCE_LABEL
      meeting_type.seeded_at = Time.current
      meeting_type.save!
    end

    definition.fetch(:item_source_keys).each_with_index do |catalog_source_key, index|
      seed_template_item(meeting_type, catalog_source_key, index + 1)
    end
  end

  def seed_template_item(meeting_type, catalog_source_key, position)
    catalog_entry = organization.agenda_item_catalog_entries.find_by!(source_key: catalog_source_key)
    source_key = "#{meeting_type.source_key}:#{catalog_source_key}"
    item = meeting_type.meeting_type_agenda_items.find_or_initialize_by(source_key: source_key)
    return unless item.new_record?

    item.agenda_item_catalog_entry = catalog_entry
    item.position = position
    item.title = catalog_entry.title
    item.summary = catalog_entry.summary
    item.active = true
    item.source_label = SOURCE_LABEL
    item.seeded_at = Time.current
    item.body = catalog_entry.body.to_s
    item.save!
  end
end
