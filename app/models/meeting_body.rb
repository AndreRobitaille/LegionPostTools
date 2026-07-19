class MeetingBody < ApplicationRecord
  belongs_to :organization
  has_many :dated_agendas, dependent: :restrict_with_exception

  normalizes :slug, with: ->(value) { value.strip.downcase }

  validates :name, :slug, :default_distribution, presence: true
  validates :slug, uniqueness: { scope: :organization_id }
end
