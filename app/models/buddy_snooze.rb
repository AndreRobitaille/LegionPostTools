class BuddySnooze < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  belongs_to :person
  validates :until_at, presence: true
end
