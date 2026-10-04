class MinutesRevision < ApplicationRecord
  belongs_to :meeting_minutes, inverse_of: :revisions
  belongs_to :approved_by, class_name: "User", optional: true
  has_one :attestation, class_name: "MinutesAttestation", dependent: :restrict_with_exception
  has_one :membership_approval,
    class_name: "MinutesMembershipApproval",
    dependent: :restrict_with_exception

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :meeting_minutes_id }
  validates :payload, :sha256, presence: true
  validates :approver_name, :approver_office, :approved_at, presence: true, if: :approved_by_id?

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def prevent_mutation
    errors.add(:base, "Approved minutes revisions are immutable.")
    throw :abort
  end
end
