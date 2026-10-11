class MembershipAssignment < ApplicationRecord
  belongs_to :membership_drive
  belongs_to :person
  belongs_to :assigned_to, class_name: "User"
  belongs_to :assigned_by, class_name: "User"
  has_many :contacts, class_name: "MembershipContact", dependent: :restrict_with_exception

  validates :person_id, uniqueness: { scope: :membership_drive_id, conditions: -> { where(revoked_at: nil) } }, if: -> { revoked_at.nil? }
  validates :expires_on, presence: true
  validate :usable_caller_and_member, on: :create
  validate :expiry_within_drive

  scope :active_on, ->(date) {
    joins(:membership_drive)
      .where(revoked_at: nil, membership_drives: { closed_at: nil })
      .where("membership_assignments.expires_on >= ? AND membership_drives.starts_on <= ? AND membership_drives.ends_on >= ?", date, date, date)
  }

  def active_on?(date = Organization.current_local_date)
    revoked_at.nil? && expires_on >= date && membership_drive.active_on?(date)
  end

  private

  def usable_caller_and_member
    errors.add(:assigned_to, "must have an enabled account") if assigned_to&.disabled_at
    errors.add(:person, "must have a National roster record") if person && !person.roster_backed?
    if person && (person.roster_removed_at.present? || person.normalized_roster_status == "deceased")
      errors.add(:person, "is removed or deceased; review the roster before assigning outreach")
    end
  end

  def expiry_within_drive
    return unless membership_drive && expires_on

    unless expires_on.between?(membership_drive.starts_on, membership_drive.ends_on)
      errors.add(:expires_on, "must fall within the drive dates")
    end
  end
end
