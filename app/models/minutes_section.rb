class MinutesSection < ApplicationRecord
  include Reorderable

  belongs_to :meeting_minutes, inverse_of: :sections
  belongs_to :source_dated_agenda_section,
    class_name: "DatedAgendaSection",
    optional: true

  has_many :items,
    -> { order(:position, :title) },
    class_name: "MinutesItem",
    dependent: :destroy,
    inverse_of: :minutes_section

  normalizes :title, with: ->(value) { value.to_s.strip }

  validates :title, presence: true
  validates :position,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :meeting_minutes_id }
  validate :source_section_belongs_to_same_meeting

  scope :ordered, -> { order(:position, :title) }

  def self.reorder!(meeting_minutes, ordered_ids)
    reorder_within!(meeting_minutes.sections, ordered_ids)
  end

  private

  def source_section_belongs_to_same_meeting
    return if source_dated_agenda_section.blank? || meeting_minutes.blank?
    return if source_dated_agenda_section.dated_agenda.meeting_id == meeting_minutes.meeting_id

    errors.add(:source_dated_agenda_section, "must belong to the same meeting")
  end
end
