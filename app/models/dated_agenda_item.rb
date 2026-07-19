class DatedAgendaItem < ApplicationRecord
  include Reorderable

  belongs_to :dated_agenda
  belongs_to :meeting_type_agenda_item, optional: true
  belongs_to :agenda_item_catalog_entry, optional: true

  has_rich_text :body

  before_validation :normalize_optional_fields
  validate :catalog_entry_belongs_to_same_organization
  validate :meeting_type_agenda_item_belongs_to_same_meeting_type
  validate :agenda_is_editable, on: %i[create update]
  before_destroy :prevent_destroy_when_locked

  validates :title, :behavior_type, presence: true
  validates :position, numericality: { only_integer: true }
  validates :position, uniqueness: { scope: :dated_agenda_id }
  validates :agenda_item_catalog_entry_id, uniqueness: { scope: :dated_agenda_id }, allow_nil: true

  scope :ordered, -> { order(:position, :title) }
  scope :active, -> { where(active: true) }

  def self.attributes_from_template_item(template_item, position:, dated_agenda:)
    {
      dated_agenda: dated_agenda,
      meeting_type_agenda_item: template_item,
      agenda_item_catalog_entry: template_item.agenda_item_catalog_entry,
      position: position,
      title: template_item.title,
      summary: template_item.summary,
      behavior_type: template_item.agenda_item_catalog_entry.behavior_type,
      active: template_item.active,
      body: template_item.body.to_s,
      source_key: template_item.source_key,
      source_label: template_item.source_label,
      seeded_at: template_item.seeded_at
    }
  end

  def self.create_from_catalog_entry!(catalog_entry, position:, dated_agenda:, meeting_type_agenda_item: nil)
    attrs = {
      dated_agenda: dated_agenda,
      agenda_item_catalog_entry: catalog_entry,
      position: position,
      title: catalog_entry.title,
      summary: catalog_entry.summary,
      behavior_type: catalog_entry.behavior_type,
      active: true,
      body: catalog_entry.body.to_s
    }
    attrs[:meeting_type_agenda_item] = meeting_type_agenda_item if meeting_type_agenda_item
    create!(attrs)
  end

  def self.reorder!(dated_agenda, ordered_ids)
    reorder_within!(dated_agenda.dated_agenda_items, ordered_ids)
  end

  private

  def normalize_optional_fields
    self.summary = summary.to_s
    self.source_key = source_key&.strip.presence
  end

  def agenda_is_editable
    return unless DatedAgenda.where(id: dated_agenda_id).pick(:status).in?(%w[approved published])

    errors.add(:base, "agenda is locked")
  end

  def prevent_destroy_when_locked
    return true unless DatedAgenda.where(id: dated_agenda_id).pick(:status).in?(%w[approved published])

    errors.add(:base, "agenda is locked")
    throw(:abort)
  end

  def catalog_entry_belongs_to_same_organization
    return if dated_agenda.blank? || agenda_item_catalog_entry.blank?
    return if dated_agenda.organization_id == agenda_item_catalog_entry.organization_id

    errors.add(:agenda_item_catalog_entry, "must belong to the same organization")
  end

  def meeting_type_agenda_item_belongs_to_same_meeting_type
    return if meeting_type_agenda_item.blank? || dated_agenda.blank?
    return if meeting_type_agenda_item.meeting_type_id == dated_agenda.meeting_type_id

    errors.add(:meeting_type_agenda_item, "must belong to the same meeting type")
  end
end
