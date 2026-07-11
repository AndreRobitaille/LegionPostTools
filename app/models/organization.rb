class Organization < ApplicationRecord
  has_many :position_titles, dependent: :destroy
  has_many :meeting_bodies, dependent: :destroy

  validates :name, :unit_type, :timezone, presence: true
end
