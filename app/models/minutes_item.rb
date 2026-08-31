class MinutesItem < ApplicationRecord
  include Reorderable

  belongs_to :minutes_section, inverse_of: :items
  belongs_to :source_dated_agenda_item,
    class_name: "DatedAgendaItem",
    optional: true
  belongs_to :endeavor, optional: true

  has_many :outcomes,
    -> { order(:position, :id) },
    class_name: "MinutesOutcome",
    dependent: :destroy,
    inverse_of: :minutes_item

  has_rich_text :agenda_body
  has_rich_text :body

  before_validation :assign_record_key, on: :create
  normalizes :title, with: ->(value) { value.to_s.strip }

  validates :record_key, :title, :behavior_type, presence: true
  validates :record_key, uniqueness: true
  validates :behavior_type,
    inclusion: { in: AgendaItemCatalogEntry::BEHAVIOR_TYPES.keys },
    allow_blank: true
  validates :position,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :minutes_section_id }
  validate :source_item_belongs_to_same_meeting
  validate :source_item_matches_source_section
  validate :endeavor_belongs_to_same_organization

  delegate :meeting_minutes, to: :minutes_section

  def self.reorder!(minutes_section, ordered_ids)
    reorder_within!(minutes_section.items, ordered_ids)
  end

  private

  def assign_record_key
    self.record_key ||= SecureRandom.uuid
  end

  def source_item_belongs_to_same_meeting
    return if source_dated_agenda_item.blank? || minutes_section.blank?
    return if source_dated_agenda_item.dated_agenda.meeting_id == meeting_minutes.meeting_id

    errors.add(:source_dated_agenda_item, "must belong to the same meeting")
  end

  def source_item_matches_source_section
    return if source_dated_agenda_item.blank? || minutes_section&.source_dated_agenda_section.blank?
    return if source_dated_agenda_item.dated_agenda_section_id == minutes_section.source_dated_agenda_section_id

    errors.add(:source_dated_agenda_item, "must belong to the source agenda section")
  end

  def endeavor_belongs_to_same_organization
    return if endeavor.blank? || minutes_section.blank?
    return if endeavor.organization_id == meeting_minutes.organization_id

    errors.add(:endeavor, "must belong to the same organization")
  end
end
