class MeetingTranscript < ApplicationRecord
  SourcePurgedError = Class.new(StandardError)

  SOURCE_KINDS = %w[pasted_text text_upload].freeze
  RETENTION_POLICIES = %w[delete_after_acceptance retain_restricted].freeze
  MAX_BYTES = 5.megabytes
  UPLOAD_MEDIA_TYPES = %w[text/plain application/octet-stream].freeze
  RECOVERY_WINDOW_SECONDS = 30.days.to_i
  RETENTION_SERVICE = "transcript_retention".freeze

  belongs_to :organization, inverse_of: :meeting_transcripts
  belongs_to :meeting, inverse_of: :transcript
  belongs_to :created_by, class_name: "User", inverse_of: :created_meeting_transcripts
  belongs_to :purged_by, class_name: "User", optional: true, inverse_of: :purged_meeting_transcripts

  has_many :draft_runs,
    class_name: "MinutesDraftRun",
    dependent: :restrict_with_exception,
    inverse_of: :meeting_transcript

  has_one_attached :text_file

  validates :source_kind, :retention_policy, :media_type, :sha256_digest, presence: true
  validates :meeting_id, uniqueness: true
  validates :source_kind, inclusion: { in: SOURCE_KINDS }
  validates :retention_policy, inclusion: { in: RETENTION_POLICIES }
  validates :byte_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sha256_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validate :meeting_belongs_to_organization
  validate :source_storage_matches_kind
  validate :uploaded_file_is_plain_text
  validate :purge_provenance_is_consistent
  validate :removal_preserves_source_metadata, on: :update

  scope :due_for_retention_purge, -> {
    joins(meeting: { minutes: { membership_approval: { minutes_revision: :attestation } } })
      .where(retention_policy: "delete_after_acceptance", purged_at: nil)
      .where(meeting_minutes: { status: "membership_approved" })
      .where("GREATEST(minutes_membership_approvals.recorded_at, minutes_attestations.attested_at) <= ?", Time.current - RECOVERY_WINDOW_SECONDS)
  }

  def source_available?
    purge_started_at.blank? && purged_at.blank? && (content.present? || text_file.attached?)
  end

  def source_text
    raise SourcePurgedError, "Transcript source is unavailable" unless source_available?

    raw = pasted_text? ? content.to_s : text_file.download
    raw.dup.force_encoding(Encoding::UTF_8).sub(/\A\uFEFF/, "").gsub("\r\n", "\n").gsub("\r", "\n")
  end

  def pasted_text? = source_kind == "pasted_text"
  def text_upload? = source_kind == "text_upload"

  def scheduled_purge_at
    return unless retention_policy == "delete_after_acceptance" && meeting.minutes&.membership_approved?

    approval = meeting.minutes.membership_approval
    attestation = approval&.minutes_revision&.attestation
    return unless approval && attestation

    [ approval.recorded_at, attestation.attested_at ].max + RECOVERY_WINDOW_SECONDS
  end

  def retention_purge_due?
    due_at = scheduled_purge_at
    purged_at.blank? && due_at.present? && due_at <= Time.current
  end

  private

  def meeting_belongs_to_organization
    return if organization.blank? || meeting.blank?
    return if meeting.organization_id == organization_id

    errors.add(:meeting, "must belong to the same organization")
  end

  def source_storage_matches_kind
    return if purged_at.present?

    if pasted_text?
      errors.add(:content, "must be present for pasted text") if content.blank?
      errors.add(:text_file, "must not be attached to pasted text") if text_file.attached?
    elsif text_upload?
      errors.add(:content, "must be blank for a text upload") if content.present?
      errors.add(:text_file, "must be attached for a text upload") unless text_file.attached?
    end
  end

  def uploaded_file_is_plain_text
    return unless text_upload? && text_file.attached?

    errors.add(:text_file, "must be 5 MB or smaller") if text_file.blob.byte_size > MAX_BYTES
    return if UPLOAD_MEDIA_TYPES.include?(text_file.blob.content_type)

    errors.add(:text_file, "must be a plain-text file")
  end

  def purge_provenance_is_consistent
    if purged_by_service.present?
      errors.add(:purged_by_service, "must identify the automatic retention service") unless purged_by_service == RETENTION_SERVICE
      errors.add(:purged_by, "must be blank for automatic removal") if purged_by.present?
      errors.add(:purge_started_at, "must be recorded for automatic removal") if purge_started_at.blank?
      errors.add(:purged_at, "must be recorded with the purging service") if purged_at.blank?
      errors.add(:content, "must be cleared before automatic removal completes") if content.present?
      errors.add(:text_file, "must be removed before automatic removal completes") if text_file.attached?
    elsif purged_at.present? && purged_by.blank?
      errors.add(:purged_by, "must be recorded when transcript source is purged")
    elsif purged_at.blank? && purged_by.present?
      errors.add(:purged_at, "must be recorded with the purging officer")
    end
  end

  def removal_preserves_source_metadata
    return unless purge_started_at_in_database.present? || purged_at_in_database.present?

    protected_fields = %w[organization_id meeting_id created_by_id source_kind retention_policy original_filename byte_size media_type sha256_digest purge_started_at]
    if protected_fields.any? { |field| will_save_change_to_attribute?(field) }
      errors.add(:base, "Transcript source metadata cannot change after removal starts.")
    end
    if purged_at_in_database.present? && %w[content purged_at purged_by_id purged_by_service].any? { |field| will_save_change_to_attribute?(field) }
      errors.add(:base, "Transcript removal evidence cannot change after completion.")
    elsif will_save_change_to_content? && !(content.nil? && purged_at.present? && purged_by_service == RETENTION_SERVICE)
      errors.add(:content, "can only be cleared when automatic removal completes")
    end
  end
end
