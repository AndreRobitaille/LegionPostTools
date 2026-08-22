class Organization < ApplicationRecord
  has_many :dated_agendas, dependent: :restrict_with_exception
  has_many :position_titles, dependent: :destroy
  has_many :meeting_bodies, dependent: :destroy
  has_many :agenda_item_catalog_entries, dependent: :destroy
  has_many :meeting_types, dependent: :destroy
  has_many :tracked_items, dependent: :restrict_with_exception

  validates :name, :unit_type, :timezone, presence: true
end
