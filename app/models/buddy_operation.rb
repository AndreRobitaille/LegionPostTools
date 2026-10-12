class BuddyOperation < ApplicationRecord
  include ImmutableMembershipEntry
  belongs_to :organization
  belongs_to :user
  belongs_to :person
  validates :operation_id, :fingerprint, :receipt, presence: true
end
