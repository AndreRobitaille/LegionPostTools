class MinutesDraftRun < ApplicationRecord
  STATUSES = %w[pending running succeeded failed].freeze

  belongs_to :meeting_minutes, inverse_of: :draft_runs
  belongs_to :meeting_transcript, inverse_of: :draft_runs
  belongs_to :requested_by, class_name: "User", inverse_of: :requested_minutes_draft_runs

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

  scope :recent, -> { order(created_at: :desc) }

  def pending? = status == "pending"
  def running? = status == "running"
  def succeeded? = status == "succeeded"
  def failed? = status == "failed"

  private

  def sources_describe_same_meeting
    return if meeting_minutes.blank? || meeting_transcript.blank?
    return if meeting_minutes.meeting_id == meeting_transcript.meeting_id

    errors.add(:base, "minutes and transcript must belong to the same meeting")
  end
end
