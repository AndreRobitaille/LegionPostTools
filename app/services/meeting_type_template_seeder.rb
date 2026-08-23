class MeetingTypeTemplateSeeder
  SOURCE_LABEL = "American Legion meeting type template seed".freeze

  MEETING_TYPES = [
    {
      name: "PEC Meeting",
      source_key: "american_legion_post:pec_meeting",
      position: 1,
      sections: [
        {
          title: "Call to Order",
          item_source_keys: [
            "regular_meeting.roll_call_quorum",
            "regular_meeting.previous_minutes"
          ]
        },
        {
          title: "Post Business",
          item_source_keys: [
            "regular_meeting.unfinished_old_business",
            "regular_meeting.new_business_correspondence",
            "regular_meeting.good_of_legion"
          ]
        }
      ]
    },
    {
      name: "Membership Meeting",
      source_key: "american_legion_post:membership_meeting",
      position: 2,
      sections: [
        {
          title: "Opening Ceremony",
          item_source_keys: [
            "regular_meeting.opening_salute_colors",
            "regular_meeting.opening_prayer",
            "regular_meeting.pow_mia_empty_chair",
            "regular_meeting.pledge_of_allegiance",
            "regular_meeting.preamble",
            "regular_meeting.opening_declaration"
          ]
        },
        {
          title: "Roll Call, Minutes & Guests",
          item_source_keys: [
            "regular_meeting.roll_call_quorum",
            "regular_meeting.previous_minutes",
            "regular_meeting.introductions"
          ]
        },
        {
          title: "Reports",
          item_source_keys: [
            "regular_meeting.finance_officer_report",
            "regular_meeting.adjutant_report",
            "regular_meeting.commander_report",
            "regular_meeting.historian_report",
            "regular_meeting.chaplain_honor_guard_report",
            "regular_meeting.programs_activities"
          ]
        },
        {
          title: "Sick Call / Service Officer",
          item_source_keys: [
            "regular_meeting.sick_call_relief_employment",
            "regular_meeting.service_officer_report"
          ]
        },
        {
          title: "Unfinished Business",
          item_source_keys: [ "regular_meeting.unfinished_old_business" ]
        },
        {
          title: "New Business",
          item_source_keys: [ "regular_meeting.new_business_correspondence" ]
        },
        {
          title: "Good of The American Legion & Announcements",
          item_source_keys: [
            "regular_meeting.good_of_legion",
            "regular_meeting.announcements"
          ]
        },
        {
          title: "Closing Ceremony & Adjournment",
          item_source_keys: [
            "regular_meeting.pow_mia_flag_retrieval",
            "regular_meeting.closing_salute_colors",
            "regular_meeting.adjournment_declaration"
          ]
        }
      ]
    }
  ].freeze

  def self.seed_for!(organization)
    new(organization).seed!
  end

  def self.defaults_missing?(organization)
    MEETING_TYPES.any? do |definition|
      meeting_type = organization.meeting_types.find_by(source_key: definition.fetch(:source_key))
      meeting_type.blank? ||
        definition.fetch(:sections).any? { |section| !meeting_type.meeting_type_agenda_sections.exists?(title: section.fetch(:title)) } ||
        meeting_type.meeting_type_agenda_items.where(source_key: seeded_item_source_keys(definition)).count < seeded_item_source_keys(definition).size
    end
  end

  def self.reset_for!(organization)
    source_keys = MEETING_TYPES.map { |definition| definition.fetch(:source_key) }
    ApplicationRecord.transaction do
      organization.meeting_types.where(source_key: source_keys).destroy_all
      seed_for!(organization)
    end
  end

  def self.reset_agenda_for!(meeting_type)
    new(meeting_type.organization).reset_agenda!(meeting_type)
  end

  def initialize(organization)
    @organization = organization
  end

  def seed!
    organization.with_lock do
      AgendaItemCatalogSeeder.seed_for!(organization)

      ApplicationRecord.transaction do
        MEETING_TYPES.each { |definition| seed_meeting_type(definition) }
      end
    end
  end

  def reset_agenda!(meeting_type)
    definition = MEETING_TYPES.find { |candidate| candidate.fetch(:source_key) == meeting_type.source_key }
    return false unless definition

    organization.with_lock do
      AgendaItemCatalogSeeder.seed_for!(organization)
      meeting_type.meeting_type_agenda_items.destroy_all
      meeting_type.meeting_type_agenda_sections.destroy_all
      seed_sections(meeting_type, definition)
    end
    true
  end

  private

  attr_reader :organization

  def seed_meeting_type(definition)
    meeting_type = organization.meeting_types.find_or_initialize_by(source_key: definition.fetch(:source_key))
    if meeting_type.new_record?
      meeting_type.name = definition.fetch(:name)
      meeting_type.position = next_available_position(definition.fetch(:position))
      meeting_type.active = true
      meeting_type.source_label = SOURCE_LABEL
      meeting_type.seeded_at = Time.current
      meeting_type.save!
    end

    meeting_type.with_lock do
      remove_unused_default_section(meeting_type)
      seed_sections(meeting_type, definition)
      resequence_sections(meeting_type) if remove_unused_default_section(meeting_type)
    end
  end

  def seed_sections(meeting_type, definition)
    definition.fetch(:sections).each_with_index do |section_definition, section_index|
      section = meeting_type.meeting_type_agenda_sections.find_or_create_by!(title: section_definition.fetch(:title)) do |new_section|
        new_section.position = next_available_section_position(meeting_type, section_index + 1)
      end
      section_definition.fetch(:item_source_keys).each_with_index do |catalog_source_key, item_index|
        seed_template_item(meeting_type, section, catalog_source_key, item_index + 1)
      end
    end
  end

  def seed_template_item(meeting_type, section, catalog_source_key, position)
    catalog_entry = organization.agenda_item_catalog_entries.find_by!(source_key: catalog_source_key)
    source_key = "#{meeting_type.source_key}:#{catalog_source_key}"
    item = meeting_type.meeting_type_agenda_items.find_or_initialize_by(source_key: source_key)
    unless item.new_record?
      move_seeded_item_to_section(item, section, position)
      return
    end

    item = MeetingTypeAgendaItem.create_from_catalog_entry!(
      catalog_entry,
      position: next_available_template_item_position(section, position),
      meeting_type: meeting_type,
      agenda_section: section
    )
    item.source_key = source_key
    item.source_label = SOURCE_LABEL
    item.seeded_at = Time.current
    item.save!
  end

  def move_seeded_item_to_section(item, section, preferred_position)
    return if item.agenda_section == section

    item.update!(
      agenda_section: section,
      position: next_available_template_item_position(section, preferred_position)
    )
  end

  def self.seeded_item_source_keys(definition)
    definition.fetch(:sections).flat_map { |section| section.fetch(:item_source_keys) }
      .map { |catalog_source_key| "#{definition.fetch(:source_key)}:#{catalog_source_key}" }
  end

  def next_available_position(preferred_position)
    taken_positions = organization.meeting_types.pluck(:position).compact.sort
    return preferred_position unless taken_positions.include?(preferred_position)

    (taken_positions.max || 0) + 1
  end

  def next_available_section_position(meeting_type, preferred_position)
    taken_positions = meeting_type.meeting_type_agenda_sections.pluck(:position).compact.sort
    return preferred_position unless taken_positions.include?(preferred_position)

    (taken_positions.max || 0) + 1
  end

  def next_available_template_item_position(section, preferred_position)
    taken_positions = section.agenda_items.pluck(:position).compact.sort
    return preferred_position unless taken_positions.include?(preferred_position)

    (taken_positions.max || 0) + 1
  end

  def remove_unused_default_section(meeting_type)
    default_section = meeting_type.meeting_type_agenda_sections.find_by(title: "Order of Business")
    return false unless default_section&.agenda_items&.empty?

    default_section.destroy!
    true
  end

  def resequence_sections(meeting_type)
    section_ids = meeting_type.meeting_type_agenda_sections.ordered.ids
    MeetingTypeAgendaSection.reorder!(meeting_type, section_ids)
  end
end
