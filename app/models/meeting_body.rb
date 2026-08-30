class MeetingBody < ApplicationRecord
  belongs_to :organization
  has_many :dated_agendas, dependent: :restrict_with_exception
  has_many :tracked_items, dependent: :nullify

  normalizes :slug, with: ->(value) { value.strip.downcase }

  validates :name, :slug, :default_distribution, presence: true
  validates :slug, uniqueness: { scope: :organization_id }

  def effective_location_name
    default_location_name.presence || organization.default_location_name
  end

  def effective_location_address
    default_location_address.presence || organization.default_location_address
  end
end
