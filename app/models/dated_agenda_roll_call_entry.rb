class DatedAgendaRollCallEntry < ApplicationRecord
  belongs_to :dated_agenda_item, inverse_of: :roll_call_entries
  belongs_to :position_title, optional: true
  belongs_to :person, optional: true

  normalizes :office_name, with: ->(value) { value.to_s.strip }
  normalizes :person_name, with: ->(value) { value.to_s.strip.presence }

  validates :office_name, presence: true
  validates :position, numericality: { only_integer: true }, uniqueness: { scope: :dated_agenda_item_id }
  validate :belongs_to_roll_call_item
  validate :position_title_belongs_to_agenda_organization
  validate :agenda_is_editable, on: %i[create update]
  before_destroy :prevent_destroy_when_locked

  def vacant?
    person_name.blank?
  end

  private

  def belongs_to_roll_call_item
    return if dated_agenda_item.blank? || dated_agenda_item.roll_call?

    errors.add(:dated_agenda_item, "must be an officer roll call")
  end

  def position_title_belongs_to_agenda_organization
    return if position_title.blank? || dated_agenda_item.blank?
    return if position_title.organization_id == dated_agenda_item.dated_agenda.organization_id

    errors.add(:position_title, "must belong to the agenda's organization")
  end

  def agenda_is_editable
    return if dated_agenda_item.blank?
    return unless dated_agenda_item.dated_agenda.locked_for_editing?

    errors.add(:base, "agenda is locked")
  end

  def prevent_destroy_when_locked
    return true if destroyed_by_association
    return true unless dated_agenda_item.dated_agenda.locked_for_editing?

    errors.add(:base, "agenda is locked")
    throw(:abort)
  end
end
