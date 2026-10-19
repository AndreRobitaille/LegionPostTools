class MinutesDistribution < ApplicationRecord
  belongs_to :organization
  belongs_to :meeting_minutes
  belongs_to :minutes_revision
  has_many :deliveries, class_name: "MinutesEmailDelivery", dependent: :restrict_with_exception
  has_one_attached :pdf

  validates :minutes_revision_id, uniqueness: true
  validates :content_digest, presence: true
  validates :state, inclusion: { in: %w[pending ready held completed superseded needs_attention] }
  validate :submitted_copy_is_frozen, on: :update
  scope :recoverable, -> { where(state: %w[pending ready]) }

  after_create_commit :enqueue_delivery

  def enqueue_delivery
    MinutesDistributionJob.perform_later(id)
  rescue StandardError => error
    Rails.logger.error("Minutes email enqueue failed issue=#{id} #{error.class}")
    # The committed issue remains available to the reconciler.
  end

  private

  def submitted_copy_is_frozen
    return unless first_submitted_at_in_database

    frozen_fields = %w[organization_id meeting_minutes_id minutes_revision_id content_digest corrected
      document_context filename pdf_sha256 template_id minutes_list_id post_members_list_id reply_to first_submitted_at]
    if (changed & frozen_fields).any?
      errors.add(:base, "The submitted minutes email copy is frozen.")
    end
  end
end
