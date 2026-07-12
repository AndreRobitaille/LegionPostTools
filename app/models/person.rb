class Person < ApplicationRecord
  has_one :user, dependent: :destroy
  has_many :position_assignments, dependent: :destroy
  has_many :position_titles, through: :position_assignments

  normalizes :roster_email_address, with: ->(value) { value&.strip&.downcase }
  normalizes :member_number, with: ->(value) { value&.strip.presence }

  validates :first_name, :last_name, presence: true
  validates :member_number, uniqueness: { allow_blank: true }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def roster_display_name
    roster_name.presence || full_name
  end

  def current_role_label
    today = Date.current
    position_assignments
      .select { |assignment| assignment.active_on?(today) }
      .map(&:position_title)
      .min_by(&:display_order)
      &.name
  end
end
