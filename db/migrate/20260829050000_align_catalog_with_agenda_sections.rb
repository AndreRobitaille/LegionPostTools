class AlignCatalogWithAgendaSections < ActiveRecord::Migration[8.1]
  class CatalogEntry < ActiveRecord::Base
    self.table_name = "agenda_item_catalog_entries"
  end

  class MeetingType < ActiveRecord::Base
    self.table_name = "meeting_types"
  end

  class TemplateSection < ActiveRecord::Base
    self.table_name = "meeting_type_agenda_sections"
  end

  class TemplateItem < ActiveRecord::Base
    self.table_name = "meeting_type_agenda_items"
  end

  class DatedItem < ActiveRecord::Base
    self.table_name = "dated_agenda_items"
  end

  class DatedSection < ActiveRecord::Base
    self.table_name = "dated_agenda_sections"
  end

  CATEGORY_DEFAULTS = {
    "regular_meeting.opening_ceremony" => [ "opening_ceremony", 1 ],
    "regular_meeting.opening_salute_colors" => [ "opening_ceremony", 2 ],
    "regular_meeting.opening_prayer" => [ "opening_ceremony", 3 ],
    "regular_meeting.pow_mia_empty_chair" => [ "opening_ceremony", 4 ],
    "regular_meeting.pledge_of_allegiance" => [ "opening_ceremony", 5 ],
    "regular_meeting.preamble" => [ "opening_ceremony", 6 ],
    "regular_meeting.opening_declaration" => [ "opening_ceremony", 7 ],
    "regular_meeting.roll_call_quorum" => [ "call_to_order", 1 ],
    "regular_meeting.previous_minutes" => [ "call_to_order", 2 ],
    "regular_meeting.introductions" => [ "call_to_order", 3 ],
    "regular_meeting.finance_officer_report" => [ "reports", 1 ],
    "regular_meeting.adjutant_report" => [ "reports", 2 ],
    "regular_meeting.commander_report" => [ "reports", 3 ],
    "regular_meeting.historian_report" => [ "reports", 4 ],
    "regular_meeting.chaplain_honor_guard_report" => [ "reports", 5 ],
    "regular_meeting.programs_activities" => [ "reports", 6 ],
    "regular_meeting.committee_reports" => [ "reports", 7 ],
    "regular_meeting.sick_call_relief_employment" => [ "service_and_welfare", 1 ],
    "regular_meeting.service_officer_report" => [ "service_and_welfare", 2 ],
    "regular_meeting.balloting_on_applications" => [ "new_business", 1 ],
    "regular_meeting.good_of_legion" => [ "good_of_legion", 1 ],
    "regular_meeting.announcements" => [ "good_of_legion", 2 ],
    "regular_meeting.pow_mia_flag_retrieval" => [ "closing_ceremony", 3 ],
    "regular_meeting.closing_salute_colors" => [ "closing_ceremony", 4 ],
    "regular_meeting.adjournment_declaration" => [ "closing_ceremony", 5 ],
    "regular_meeting.memorial_departed_member" => [ "special", 1 ]
  }.freeze

  LEGACY_CATEGORY_FALLBACKS = {
    "ceremony" => "special",
    "business" => "new_business",
    "membership" => "new_business",
    "memorial" => "special",
    "administration" => "call_to_order"
  }.freeze

  RETIRED_CATALOG_SOURCE_KEYS = %w[
    regular_meeting.closing_ceremony
    regular_meeting.unfinished_old_business
    regular_meeting.new_business_correspondence
  ].freeze

  RETIRED_TEMPLATE_SOURCE_KEYS = %w[
    american_legion_post:pec_meeting:regular_meeting.unfinished_old_business
    american_legion_post:pec_meeting:regular_meeting.new_business_correspondence
    american_legion_post:membership_meeting:regular_meeting.unfinished_old_business
    american_legion_post:membership_meeting:regular_meeting.new_business_correspondence
  ].freeze

  def up
    transaction do
      reclassify_catalog
      retire_catalog_placeholders
      normalize_catalog_positions
      retire_template_placeholders
      reshape_pec_template
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "section placeholders cannot be restored without overwriting local agenda structure"
  end

  private

  def reclassify_catalog
    CatalogEntry.find_each do |entry|
      category, position = CATEGORY_DEFAULTS[entry.source_key]
      category ||= LEGACY_CATEGORY_FALLBACKS[entry.category]
      next unless category

      attributes = { category: category, updated_at: Time.current }
      attributes[:position] = position if position
      attributes[:behavior_type] = "report_slot" if entry.source_key == "regular_meeting.committee_reports" && entry.behavior_type == "section_heading"
      entry.update_columns(attributes)
    end
  end

  def normalize_catalog_positions
    CatalogEntry.where(removed_from_catalog_at: nil).distinct.pluck(:organization_id, :category).each do |organization_id, category|
      entries = CatalogEntry.where(organization_id: organization_id, category: category, removed_from_catalog_at: nil)
        .order(:position, :title, :id)
      entries.each_with_index do |entry, index|
        entry.update_columns(position: index + 1, updated_at: Time.current) unless entry.position == index + 1
      end
    end
  end

  def retire_catalog_placeholders
    CatalogEntry.where(source_key: RETIRED_CATALOG_SOURCE_KEYS, removed_from_catalog_at: nil)
      .update_all(removed_from_catalog_at: Time.current, updated_at: Time.current)
  end

  def retire_template_placeholders
    TemplateItem.where(source_key: RETIRED_TEMPLATE_SOURCE_KEYS).find_each do |item|
      if DatedItem.exists?(meeting_type_agenda_item_id: item.id)
        item.update_columns(active: false, updated_at: Time.current)
      else
        execute <<~SQL.squish
          DELETE FROM action_text_rich_texts
          WHERE record_type = 'MeetingTypeAgendaItem' AND record_id = #{connection.quote(item.id)}
        SQL
        item.delete
      end
    end
  end

  def reshape_pec_template
    MeetingType.where(source_key: "american_legion_post:pec_meeting").find_each do |meeting_type|
      reuse_pec_post_business_section(meeting_type)
      desired_titles = [ "Call to Order", "Unfinished Business", "New Business", "Good of The American Legion" ]
      sections = desired_titles.index_with do |title|
        TemplateSection.find_or_create_by!(meeting_type_id: meeting_type.id, title: title) do |section|
          section.position = next_temporary_section_position(meeting_type.id)
        end
      end

      good_item = TemplateItem.find_by(source_key: "american_legion_post:pec_meeting:regular_meeting.good_of_legion")
      move_item_to_section(good_item, sections.fetch("Good of The American Legion")) if good_item

      move_retired_pec_item(
        meeting_type,
        "regular_meeting.unfinished_old_business",
        sections.fetch("Unfinished Business")
      )
      move_retired_pec_item(
        meeting_type,
        "regular_meeting.new_business_correspondence",
        sections.fetch("New Business")
      )

      post_business = TemplateSection.find_by(meeting_type_id: meeting_type.id, title: "Post Business")
      delete_post_business_section(post_business) if post_business

      ordered = desired_titles.filter_map { |title| sections[title] }
      extras = TemplateSection.where(meeting_type_id: meeting_type.id).where.not(id: ordered.map(&:id)).order(:position, :id)
      resequence_sections(ordered + extras)
    end
  end

  def reuse_pec_post_business_section(meeting_type)
    sections = TemplateSection.where(meeting_type_id: meeting_type.id)
    post_business = sections.find_by(title: "Post Business")
    return unless post_business && !sections.exists?(title: "Unfinished Business")

    post_business.update_columns(title: "Unfinished Business", updated_at: Time.current)
  end

  def delete_post_business_section(section)
    return if TemplateItem.exists?(meeting_type_agenda_section_id: section.id)
    return if DatedSection.exists?(meeting_type_agenda_section_id: section.id)

    section.delete
  end

  def move_item_to_section(item, section)
    return if item.meeting_type_agenda_section_id == section.id

    next_position = TemplateItem.where(meeting_type_agenda_section_id: section.id).maximum(:position).to_i + 1
    item.update_columns(
      meeting_type_agenda_section_id: section.id,
      position: next_position,
      updated_at: Time.current
    )
  end

  def move_retired_pec_item(meeting_type, catalog_source_key, section)
    source_key = "#{meeting_type.source_key}:#{catalog_source_key}"
    item = TemplateItem.find_by(meeting_type_id: meeting_type.id, source_key: source_key)
    move_item_to_section(item, section) if item
  end

  def next_temporary_section_position(meeting_type_id)
    TemplateSection.where(meeting_type_id: meeting_type_id).maximum(:position).to_i + 1
  end

  def resequence_sections(sections)
    offset = sections.map(&:position).max.to_i + sections.length + 1
    sections.each_with_index { |section, index| section.update_columns(position: offset + index) }
    sections.each_with_index { |section, index| section.update_columns(position: index + 1, updated_at: Time.current) }
  end
end
