class MeetingBody < ApplicationRecord
  belongs_to :organization

  normalizes :slug, with: ->(value) { value.strip.downcase }

  validates :name, :slug, :default_distribution, presence: true
  validates :slug, uniqueness: { scope: :organization_id }
end
