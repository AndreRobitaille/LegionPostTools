class User < ApplicationRecord
  belongs_to :person
  has_many :permission_grants, dependent: :destroy

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :person_id, uniqueness: true

  def can?(capability)
    permission_grants.exists?(capability: capability.to_s)
  end
end
