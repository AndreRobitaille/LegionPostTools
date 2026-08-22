class MeetingTypeAgendaSection < ApplicationRecord
  include Reorderable

  belongs_to :meeting_type
  has_many :agenda_items,
    -> { order(:position, :title) },
    class_name: "MeetingTypeAgendaItem",
    foreign_key: :meeting_type_agenda_section_id,
    inverse_of: :agenda_section,
    dependent: :restrict_with_error

  normalizes :title, with: ->(value) { value.to_s.strip }

  validates :title, presence: true, uniqueness: { scope: :meeting_type_id }
  validates :position, numericality: { only_integer: true }, uniqueness: { scope: :meeting_type_id }

  scope :ordered, -> { order(:position, :title) }

  def self.reorder!(meeting_type, ordered_ids)
    reorder_within!(meeting_type.meeting_type_agenda_sections, ordered_ids)
  end
end
