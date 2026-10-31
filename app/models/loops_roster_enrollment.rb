class LoopsRosterEnrollment < ApplicationRecord
  belongs_to :organization
  validates :member_user_id, :email, :loops_contact_id, :list_id, presence: true
end
