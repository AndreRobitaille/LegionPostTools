class MeetingMinutes < ApplicationRecord
  STATUSES = %w[draft approved attested accepted].freeze

  belongs_to :organization, inverse_of: :meeting_minutes
  belongs_to :meeting, inverse_of: :minutes
  belongs_to :meeting_body, inverse_of: :meeting_minutes
  belongs_to :meeting_type, optional: true, inverse_of: :meeting_minutes

  has_many :sections,
    -> { order(:position, :title) },
    class_name: "MinutesSection",
    dependent: :destroy,
    inverse_of: :meeting_minutes
  has_many :items, through: :sections
  has_many :attendance_entries,
    -> { order(:position, :office_name) },
    class_name: "MinutesAttendanceEntry",
    dependent: :destroy,
    inverse_of: :meeting_minutes
  has_many :draft_runs,
    -> { order(created_at: :desc) },
    class_name: "MinutesDraftRun",
    dependent: :restrict_with_exception,
    inverse_of: :meeting_minutes

  normalizes :title, :location_name, with: ->(value) { value.to_s.strip }

  validates :title, :starts_at, :location_name, :status, presence: true
  validates :meeting_id, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validate :associations_describe_same_meeting

  scope :draft, -> { where(status: "draft") }

  def self.create_from_meeting!(meeting:)
    meeting.with_lock do
      if meeting.minutes.present?
        meeting.minutes.errors.add(:meeting, "already has a minutes record")
        raise ActiveRecord::RecordInvalid, meeting.minutes
      end

      if meeting.starts_at > Time.current
        meeting.errors.add(:starts_at, "must be in the past before minutes can begin")
        raise ActiveRecord::RecordInvalid, meeting
      end

      agenda = meeting.dated_agenda
      heading_source = agenda&.locked_for_editing? ? agenda : meeting
      minutes = create!(
        organization: meeting.organization,
        meeting: meeting,
        meeting_body: meeting.meeting_body,
        meeting_type: meeting.meeting_type,
        title: heading_source.title,
        starts_at: heading_source.starts_at,
        location_name: heading_source.location_name,
        location_address: heading_source.location_address,
        status: "draft"
      )

      minutes.seed_from_agenda!(agenda) if agenda.present?
      minutes.sections.create!(title: "Meeting record", position: 1) if minutes.sections.empty?
      minutes
    end
  end

  def draft? = status == "draft"
  def approved? = status == "approved"
  def attested? = status == "attested"
  def accepted? = status == "accepted"

  def seed_from_agenda!(agenda)
    attendance_position = 0

    agenda.dated_agenda_sections.ordered.includes(
      agenda_items: [ :endeavor, :rich_text_body, :rich_text_commander_notes, { roll_call_entries: %i[position_title person] } ]
    ).each do |agenda_section|
      section = sections.create!(
        source_dated_agenda_section: agenda_section,
        title: agenda_section.title,
        position: agenda_section.position
      )

      agenda_section.agenda_items.active.order(:position, :title).each do |agenda_item|
        item = section.items.create!(
          source_dated_agenda_item: agenda_item,
          endeavor: agenda_item.endeavor,
          title: agenda_item.title,
          behavior_type: agenda_item.behavior_type,
          position: agenda_item.position
        )
        if agenda_item.show_wording_in_minutes? && agenda_item.rich_text_body.present?
          item.create_rich_text_agenda_body!(body: agenda_item.rich_text_body.body)
        end

        agenda_item.roll_call_entries.each do |roll_call_entry|
          attendance_position += 1
          attendance_entries.create!(
            dated_agenda_roll_call_entry: roll_call_entry,
            position_title: roll_call_entry.position_title,
            person: roll_call_entry.person,
            office_name: roll_call_entry.office_name,
            person_name: roll_call_entry.person_name,
            status: roll_call_entry.vacant? ? "vacant" : "not_recorded",
            position: attendance_position
          )
        end
      end
    end
  end

  private

  def associations_describe_same_meeting
    return if organization.blank? || meeting.blank? || meeting_body.blank?

    unless meeting.organization_id == organization_id && meeting.meeting_body_id == meeting_body_id
      errors.add(:base, "organization, meeting, and meeting body must describe the same occurrence")
    end

    if meeting_type_id != meeting.meeting_type_id
      errors.add(:meeting_type, "must match the meeting")
    end
  end
end
