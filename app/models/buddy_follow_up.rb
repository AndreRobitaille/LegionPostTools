class BuddyFollowUp < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  belongs_to :person
  belongs_to :membership_contact, optional: true
  validates :status, inclusion: { in: %w[open completed cancelled] }
  validates :due_at, :entry_zone, presence: true
end
