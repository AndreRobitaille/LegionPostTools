class DatedAgendaSection < ApplicationRecord
  include Reorderable

  belongs_to :dated_agenda
  belongs_to :meeting_type_agenda_section, optional: true
  has_many :agenda_items,
    -> { order(:position, :title) },
    class_name: "DatedAgendaItem",
    foreign_key: :dated_agenda_section_id,
    inverse_of: :agenda_section,
    dependent: :restrict_with_error

  normalizes :title, with: ->(value) { value.to_s.strip }

  validates :title, presence: true, uniqueness: { scope: :dated_agenda_id }
  validates :position, numericality: { only_integer: true }, uniqueness: { scope: :dated_agenda_id }
  validate :source_section_matches_template
  validate :agenda_is_editable, on: %i[create update]
  before_destroy :prevent_destroy_when_locked

  scope :ordered, -> { order(:position, :title) }

  def self.reorder!(dated_agenda, ordered_ids)
    reorder_within!(dated_agenda.dated_agenda_sections, ordered_ids)
  end

  private

  def source_section_matches_template
    return if meeting_type_agenda_section.blank? || dated_agenda.blank?
    return if meeting_type_agenda_section.meeting_type_id == dated_agenda.meeting_type_id

    errors.add(:meeting_type_agenda_section, "must belong to the agenda's meeting type")
  end

  def agenda_is_editable
    return unless DatedAgenda.where(id: dated_agenda_id).pick(:status).in?(%w[approved published])

    errors.add(:base, "agenda is locked")
  end

  def prevent_destroy_when_locked
    return true if destroyed_by_association
    return true unless DatedAgenda.where(id: dated_agenda_id).pick(:status).in?(%w[approved published])

    errors.add(:base, "agenda is locked")
    throw(:abort)
  end
end
