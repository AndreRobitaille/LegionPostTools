class MinutesEmailDelivery < ApplicationRecord
  belongs_to :minutes_distribution
  validates :email, :idempotency_key, presence: true
  validates :status, inclusion: { in: %w[pending submitting retry sent skipped unchanged superseded needs_attention] }

  scope :unresolved, -> { where(status: %w[pending submitting retry]) }
end
