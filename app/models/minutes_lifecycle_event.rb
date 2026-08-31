class MinutesLifecycleEvent < ApplicationRecord
  EVENT_TYPES = %w[approved attested].freeze

  belongs_to :meeting_minutes, inverse_of: :lifecycle_events
  belongs_to :minutes_revision
  belongs_to :actor, class_name: "User"
  belongs_to :recorded_by, class_name: "User"
  belongs_to :official_action_confirmation

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :from_status, :to_status, :actor_name, :actor_office, :occurred_at, presence: true

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def prevent_mutation
    errors.add(:base, "Minutes lifecycle events are append-only.")
    throw :abort
  end
end
