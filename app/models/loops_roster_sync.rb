class LoopsRosterSync < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze

  belongs_to :roster_import
  belongs_to :requested_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :eligible_count, :synced_count, :failed_count, :missing_email_count,
    :invalid_email_count, :shared_email_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :active, -> { where(status: %w[queued running]) }

  def active?
    status.in?(%w[queued running])
  end
end
