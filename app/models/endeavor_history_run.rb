class EndeavorHistoryRun < ApplicationRecord
  belongs_to :endeavor
  belongs_to :requested_by, class_name: "User", optional: true
  has_one :edition, class_name: "EndeavorHistoryEdition", dependent: :restrict_with_exception
  scope :active, -> { where(status: %w[pending running]) }
  scope :recent, -> { order(id: :desc) }
  validates :fingerprint, :manifest, presence: true
  validates :status, inclusion: { in: %w[pending running succeeded failed superseded] }

  def terminal? = status.in?(%w[succeeded failed superseded])
  def tokens = steps.sum { |step| step.fetch("total_tokens", 0).to_i }
end
