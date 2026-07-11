class Person < ApplicationRecord
  has_one :user, dependent: :destroy
  has_many :position_assignments, dependent: :destroy
  has_many :position_titles, through: :position_assignments

  validates :first_name, :last_name, presence: true

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end
end
