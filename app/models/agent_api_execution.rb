class AgentApiExecution < ApplicationRecord
  RETENTION_PERIOD = 30.days

  belongs_to :agent_access_token
  belongs_to :user

  validates :idempotency_key, :request_method, :request_path, :request_fingerprint, :state, presence: true
  validates :idempotency_key, length: { maximum: 255 }
  validates :idempotency_key, uniqueness: { scope: :agent_access_token_id }
  validates :state, inclusion: { in: %w[processing completed] }

  scope :expired, -> { where(created_at: ...RETENTION_PERIOD.ago) }

  def completed?
    state == "completed"
  end
end
