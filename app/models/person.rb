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

  def service_summary
    [ roster_branch, roster_war_era ].compact_blank.join(" · ")
  end

  def paid_up_for_life?
    roster_membership_type.to_s.downcase.include?("paid up for life")
  end

  def roster_paid_through_display
    return "Paid up for life" if paid_up_for_life?
    return "Paid through: #{roster_paid_through_year}" if roster_paid_through_year.present?

    ""
  end

  def active_role_labels(today = Date.current)
    position_assignments
      .select { |assignment| assignment.active_on?(today) }
      .sort_by { |assignment| [ assignment.position_title.display_order, assignment.position_title.name ] }
      .map { |assignment| assignment.position_title.name }
  end
end
