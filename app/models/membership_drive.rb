class MembershipDrive < ApplicationRecord
  PURPOSES = { "renewal" => "Membership renewal", "welcome" => "New member welcome", "buddy_check" => "Buddy Check" }.freeze

  belongs_to :organization
  belongs_to :created_by, class_name: "User"
  has_many :assignments, class_name: "MembershipAssignment", dependent: :restrict_with_exception

  validates :title, :starts_on, :ends_on, presence: true
  validates :title, length: { maximum: 160 }
  validates :script, length: { maximum: 5000 }
  validates :purpose, inclusion: { in: PURPOSES.keys }
  validates :membership_year, inclusion: { in: MembershipReport::VALID_YEARS }
  validate :dates_in_order

  scope :open, -> { where(closed_at: nil) }

  def active_on?(date = Organization.current_local_date)
    closed_at.nil? && starts_on <= date && ends_on >= date
  end

  private

  def dates_in_order
    errors.add(:ends_on, "must be on or after the start date") if starts_on && ends_on && ends_on < starts_on
  end
end
