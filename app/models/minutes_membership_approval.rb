class MinutesMembershipApproval < ApplicationRecord
  DISPOSITIONS = %w[
    approved_as_presented
    approved_as_corrected
    approved_by_motion
    other
  ].freeze

  belongs_to :meeting_minutes, inverse_of: :membership_approval
  belongs_to :minutes_revision, inverse_of: :membership_approval
  belongs_to :approving_meeting,
    class_name: "Meeting",
    inverse_of: :minutes_membership_approvals
  belongs_to :recorded_by, class_name: "User"
  belongs_to :official_action_confirmation

  validates :meeting_minutes_id, :minutes_revision_id, uniqueness: true
  validates :disposition, inclusion: { in: DISPOSITIONS }
  validates :recorder_name, :recorder_office, :recorded_at, presence: true
  validates :factual_note, presence: true, if: -> { disposition == "other" }
  validate :revision_belongs_to_minutes
  validate :records_same_body_later_meeting

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  def disposition_label
    {
      "approved_as_presented" => "Approved as presented",
      "approved_as_corrected" => "Approved as corrected",
      "approved_by_motion" => "Approved by recorded motion",
      "other" => "Approved by another recorded procedure"
    }.fetch(disposition)
  end

  private

  def revision_belongs_to_minutes
    return if meeting_minutes.blank? || minutes_revision.blank?
    return if minutes_revision.meeting_minutes_id == meeting_minutes_id

    errors.add(:minutes_revision, "must belong to these minutes")
  end

  def records_same_body_later_meeting
    return if meeting_minutes.blank? || approving_meeting.blank?

    unless approving_meeting.organization_id == meeting_minutes.organization_id &&
        approving_meeting.meeting_body_id == meeting_minutes.meeting_body_id
      errors.add(:approving_meeting, "must belong to the same organization and meeting body")
    end
    unless approving_meeting.starts_at > meeting_minutes.starts_at
      errors.add(:approving_meeting, "must be later than the minutes meeting")
    end
    if approving_meeting.starts_at > Time.current
      errors.add(:approving_meeting, "must already have occurred")
    end
  end

  def prevent_mutation
    errors.add(:base, "Membership approval records are append-only.")
    throw :abort
  end
end
