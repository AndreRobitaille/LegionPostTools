class MeetingTypeAgendaItem < ApplicationRecord
  belongs_to :meeting_type
  belongs_to :agenda_section,
    class_name: "MeetingTypeAgendaSection",
    foreign_key: :meeting_type_agenda_section_id,
    inverse_of: :agenda_items
  belongs_to :agenda_item_catalog_entry
  has_rich_text :body

  include Reorderable

  before_validation :normalize_optional_fields
  before_validation :assign_default_agenda_section

  validates :title, presence: true
  validates :position, numericality: { only_integer: true }
  validates :position, uniqueness: { scope: :meeting_type_agenda_section_id }
  validates :agenda_item_catalog_entry_id, uniqueness: { scope: :meeting_type_id }
  validates :source_key, uniqueness: { scope: :meeting_type_id }, allow_blank: true
  validate :catalog_entry_belongs_to_same_organization
  validate :agenda_section_belongs_to_same_meeting_type

  scope :ordered, -> {
    joins(:agenda_section).order("meeting_type_agenda_sections.position", "meeting_type_agenda_items.position", "meeting_type_agenda_items.title")
  }
  # Unused by this feature since soft-delete removal; retained for potential future per-item visibility.
  scope :active, -> { where(active: true) }

  def self.reorder!(container, ordered_ids)
    agenda_section = container.is_a?(MeetingTypeAgendaSection) ? container : container.default_agenda_section
    reorder_within!(agenda_section.agenda_items, ordered_ids)
  end

  def self.create_from_catalog_entry!(catalog_entry, position:, meeting_type: nil, agenda_section: nil)
    attributes = {
      agenda_item_catalog_entry: catalog_entry,
      position: position,
      title: catalog_entry.title,
      summary: catalog_entry.summary,
      active: true,
      body: catalog_entry.body.to_s
    }

    attributes[:agenda_section] = agenda_section || meeting_type&.default_agenda_section
    meeting_type ? meeting_type.meeting_type_agenda_items.create!(attributes) : create!(attributes)
  end

  def seeded?
    source_key.present?
  end

  private

  def normalize_optional_fields
    self.summary = summary.to_s
    self.source_key = source_key&.strip.presence
  end

  def assign_default_agenda_section
    self.agenda_section ||= meeting_type&.default_agenda_section
  end

  def catalog_entry_belongs_to_same_organization
    return if meeting_type.blank? || agenda_item_catalog_entry.blank?
    return if meeting_type.organization_id == agenda_item_catalog_entry.organization_id

    errors.add(:agenda_item_catalog_entry, "must belong to the same organization")
  end

  def agenda_section_belongs_to_same_meeting_type
    return if meeting_type.blank? || agenda_section.blank?
    return if agenda_section.meeting_type_id == meeting_type_id

    errors.add(:agenda_section, "must belong to the same meeting type")
  end
end
