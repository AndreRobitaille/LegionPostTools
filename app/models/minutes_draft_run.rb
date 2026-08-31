class MinutesDraftRun < ApplicationRecord
  STATUSES = %w[pending running succeeded failed].freeze

  belongs_to :meeting_minutes, inverse_of: :draft_runs
  belongs_to :meeting_transcript, inverse_of: :draft_runs
  belongs_to :requested_by, class_name: "User", inverse_of: :requested_minutes_draft_runs
  belongs_to :retry_of,
    class_name: "MinutesDraftRun",
    optional: true,
    inverse_of: :retries
  belongs_to :discarded_by,
    class_name: "User",
    optional: true,
    inverse_of: :discarded_minutes_draft_runs

  has_many :retries,
    class_name: "MinutesDraftRun",
    foreign_key: :retry_of_id,
    dependent: :restrict_with_exception,
    inverse_of: :retry_of

  has_many :suggestions,
    -> { order(:id) },
    class_name: "MinutesDraftSuggestion",
    dependent: :destroy,
    inverse_of: :minutes_draft_run

  validates :provider, :model, :reasoning_effort, :text_verbosity, :prompt_version, :prompt_sha256,
    :schema_version, :source_sha256, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source_line_count, numericality: { only_integer: true, greater_than: 0 }
  validate :sources_describe_same_meeting
  validate :retry_describes_same_minutes
  validate :discard_provenance_is_complete

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[pending running]) }
  scope :failed, -> { where(status: "failed") }
  scope :kept_for_attention, -> { where(discarded_at: nil) }

  def pending? = status == "pending"
  def running? = status == "running"
  def succeeded? = status == "succeeded"
  def failed? = status == "failed"
  def discarded? = discarded_at.present?

  private

  def sources_describe_same_meeting
    return if meeting_minutes.blank? || meeting_transcript.blank?
    return if meeting_minutes.meeting_id == meeting_transcript.meeting_id

    errors.add(:base, "minutes and transcript must belong to the same meeting")
  end

  def retry_describes_same_minutes
    return if retry_of.blank? || meeting_minutes.blank?
    return if retry_of.meeting_minutes_id == meeting_minutes_id

    errors.add(:retry_of, "must belong to the same minutes record")
  end

  def discard_provenance_is_complete
    return if discarded_by.blank? || discarded_at.present?

    errors.add(:discarded_at, "must be recorded when a discarding person is present")
  end
end
