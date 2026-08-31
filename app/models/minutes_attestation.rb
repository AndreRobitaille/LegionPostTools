class MinutesAttestation < ApplicationRecord
  belongs_to :minutes_revision
  belongs_to :attested_by, class_name: "User"
  belongs_to :recorded_by, class_name: "User"
  belongs_to :official_action_confirmation

  validates :minutes_revision_id, uniqueness: true
  validates :attester_name, :attester_office, :attested_at, presence: true

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def prevent_mutation
    errors.add(:base, "Minutes attestations are append-only.")
    throw :abort
  end
end
