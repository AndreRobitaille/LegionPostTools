class MinutesAttendanceEntry < ApplicationRecord
  STATUSES = %w[present absent excused vacant not_recorded].freeze

  belongs_to :meeting_minutes, inverse_of: :attendance_entries
  belongs_to :dated_agenda_roll_call_entry, optional: true
  belongs_to :position_title, optional: true
  belongs_to :person, optional: true

  normalizes :office_name, with: ->(value) { value.to_s.strip }
  normalizes :person_name, with: ->(value) { value.to_s.strip.presence }

  validates :office_name, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :position,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :meeting_minutes_id }
  validate :source_entry_belongs_to_same_meeting
  validate :position_title_belongs_to_same_organization

  private

  def source_entry_belongs_to_same_meeting
    return if dated_agenda_roll_call_entry.blank? || meeting_minutes.blank?
    source_meeting_id = dated_agenda_roll_call_entry.dated_agenda_item.dated_agenda.meeting_id
    return if source_meeting_id == meeting_minutes.meeting_id

    errors.add(:dated_agenda_roll_call_entry, "must belong to the same meeting")
  end

  def position_title_belongs_to_same_organization
    return if position_title.blank? || meeting_minutes.blank?
    return if position_title.organization_id == meeting_minutes.organization_id

    errors.add(:position_title, "must belong to the same organization")
  end
end
