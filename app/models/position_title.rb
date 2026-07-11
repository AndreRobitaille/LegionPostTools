class PositionTitle < ApplicationRecord
  belongs_to :organization
  has_many :position_assignments, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :display_order, numericality: { only_integer: true }
end
