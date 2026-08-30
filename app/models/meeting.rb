class Meeting < ApplicationRecord
  HEADING_FIELDS = %w[starts_at title location_name location_address].freeze

  belongs_to :organization
  belongs_to :meeting_body
  belongs_to :meeting_type, optional: true

  has_one :dated_agenda, dependent: :restrict_with_exception
  has_one :minutes,
    class_name: "MeetingMinutes",
    dependent: :restrict_with_exception,
    inverse_of: :meeting
  has_one :transcript,
    class_name: "MeetingTranscript",
    dependent: :restrict_with_exception,
    inverse_of: :meeting

  before_validation :apply_default_title
  before_validation :apply_location_defaults, on: :create
  after_update :sync_draft_agenda_heading!

  validates :title, :starts_at, :location_name, presence: true
  validate :associations_belong_to_same_organization
  validate :document_boundaries_are_respected, on: :update

  scope :ordered, -> { order("meetings.starts_at DESC", "meetings.title ASC") }
  scope :upcoming, -> { where("meetings.starts_at >= ?", Time.zone.today.beginning_of_day).order("meetings.starts_at ASC", "meetings.title ASC") }
  scope :past, -> { where("meetings.starts_at < ?", Time.zone.today.beginning_of_day).order("meetings.starts_at DESC", "meetings.title ASC") }

  def self.default_title(meeting_body:, meeting_type:, starts_at:)
    name = meeting_type&.name.presence || meeting_body&.name.presence || "Meeting"
    return name if starts_at.blank?

    "#{name} — #{starts_at.in_time_zone.strftime('%d %b %Y').upcase}"
  end

  def update_with_agenda_sync(attributes)
    transaction { update(attributes) }
  rescue ActiveRecord::RecordInvalid
    false
  end

  def empty_record?
    dated_agenda.nil? && minutes.nil? && transcript.nil?
  end

  private

  def apply_default_title
    self.title = self.class.default_title(meeting_body:, meeting_type:, starts_at:) if title.blank?
  end

  def apply_location_defaults
    self.location_name = meeting_body&.effective_location_name if location_name.blank?
    self.location_address = meeting_body&.effective_location_address if location_address.blank?
  end

  def document_boundaries_are_respected
    return if dated_agenda.nil?

    if will_save_change_to_meeting_body_id? || will_save_change_to_meeting_type_id?
      errors.add(:base, "Remove the draft agenda before changing the meeting body or meeting type.")
    end

    if dated_agenda.locked_for_editing? && (changes.keys & HEADING_FIELDS).any?
      errors.add(:base, "Reopen the agenda before changing this meeting's date, title, or place.")
    end
  end

  def sync_draft_agenda_heading!
    return unless dated_agenda&.draft?
    return if (saved_changes.keys & HEADING_FIELDS).empty?

    dated_agenda.update!(
      starts_at: starts_at,
      title: title,
      location_name: location_name,
      location_address: location_address
    )
  end

  def associations_belong_to_same_organization
    return if organization.blank? || meeting_body.blank?

    errors.add(:meeting_body, "must belong to the same organization") if meeting_body.organization_id != organization_id
    if meeting_type.present? && meeting_type.organization_id != organization_id
      errors.add(:meeting_type, "must belong to the same organization")
    end
  end
end
