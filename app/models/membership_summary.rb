class MembershipSummary < ApplicationRecord
  include ImmutableMembershipEntry

  belongs_to :organization
  belongs_to :created_by, class_name: "User"

  validates :membership_year, inclusion: { in: MembershipReport::VALID_YEARS }
  validates :payload, :submission_key, presence: true
  validates :submission_key, uniqueness: true, length: { maximum: 100 }
end
