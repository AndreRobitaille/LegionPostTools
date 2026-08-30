class MeetingTranscript < ApplicationRecord
  SourcePurgedError = Class.new(StandardError)

  SOURCE_KINDS = %w[pasted_text text_upload].freeze
  RETENTION_POLICIES = %w[delete_after_acceptance retain_restricted].freeze
  MAX_BYTES = 5.megabytes
  UPLOAD_MEDIA_TYPES = %w[text/plain application/octet-stream].freeze

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

  def source_available?
    purged_at.blank? && (content.present? || text_file.attached?)
  end

  def source_text
    raise SourcePurgedError, "Transcript source has been purged" unless source_available?

    raw = pasted_text? ? content.to_s : text_file.download
    raw.encode("UTF-8").sub(/\A\uFEFF/, "").gsub("\r\n", "\n").gsub("\r", "\n")
  end

  def pasted_text? = source_kind == "pasted_text"
  def text_upload? = source_kind == "text_upload"

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
    if purged_at.present? && purged_by.blank?
      errors.add(:purged_by, "must be recorded when transcript source is purged")
    elsif purged_at.blank? && purged_by.present?
      errors.add(:purged_at, "must be recorded with the purging officer")
    end
  end
end
