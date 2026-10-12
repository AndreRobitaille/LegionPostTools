class MembershipContact < ApplicationRecord
  include ImmutableMembershipEntry

  CHANNELS = { "phone" => "Phone", "in_person" => "In person", "email" => "Email", "postal_mail" => "Postal mail", "website" => "Website", "text" => "Text message", "administrative_review" => "Officer review of a recorded result" }.freeze
  OUTCOMES = {
    "wrong_number" => "Wrong number", "not_attempted" => "Not attempted",
    "no_answer" => "No answer", "message_left" => "Message left", "reached" => "Reached",
    "callback_requested" => "Callback requested", "already_paid_online" => "Reports paid through National",
    "wants_to_renew" => "Wants help renewing", "declined_renewal" => "Declined renewal",
    "do_not_contact" => "Do not contact for this purpose", "officer_review" => "Officer review needed",
    "contact_permission_restored" => "Contact permission restored by officer"
  }.freeze

  belongs_to :supersedes_contact, class_name: "MembershipContact", optional: true
  belongs_to :logical_contact, class_name: "MembershipContact", optional: true

  belongs_to :organization
  belongs_to :person
  belongs_to :recorded_by, class_name: "User"
  belongs_to :membership_assignment, optional: true

  normalizes :paper_reference, with: ->(value) { value&.strip.presence }

  validates :membership_year, inclusion: { in: MembershipReport::VALID_YEARS }
  validates :purpose, inclusion: { in: MembershipDrive::PURPOSES.keys }
  validates :channel, inclusion: { in: CHANNELS.keys }
  validates :outcome, inclusion: { in: OUTCOMES.keys }
  validates :occurred_on, :submission_key, presence: true
  validates :submission_key, uniqueness: true, length: { maximum: 100 }
  validates :notes, length: { maximum: 2000 }
  validates :paper_reference, uniqueness: true, length: { maximum: 100 }, allow_nil: true
  validates :follow_up_on, presence: true, if: -> { outcome == "callback_requested" }
  validates :notes, presence: true, if: -> { outcome == "contact_permission_restored" || channel == "administrative_review" }
  validate :contact_dates
  validate :assignment_matches_contact

  scope :effective, -> { where.not(id: MembershipContact.where.not(supersedes_contact_id: nil).select(:supersedes_contact_id)) }
  scope :for_workspace_year, ->(year) { where(membership_year: year).or(where(purpose: "buddy_check")) }
  scope :recent, -> { order(occurred_on: :desc, created_at: :desc, id: :desc) }
  # A returned sheet lacks the time needed to replace digital work from that day.
  scope :for_current_work, -> {
    effective.order(occurred_on: :desc).order(Arel.sql("CASE WHEN paper_reference IS NULL THEN 0 ELSE 1 END ASC"))
      .order(Arel.sql("COALESCE(occurred_at, created_at) DESC")).order(id: :desc)
  }

  private

  def contact_dates
    if follow_up_on_before_type_cast.present? && follow_up_on.nil?
      errors.add(:follow_up_on, "must be a valid date")
    end
    errors.add(:occurred_on, "cannot be in the future") if occurred_on && occurred_on > Organization.current_local_date
    if follow_up_on && occurred_on && follow_up_on < occurred_on && supersedes_contact_id.nil?
      errors.add(:follow_up_on, "must be on or after the contact date")
    end
  end

  def assignment_matches_contact
    if purpose == "buddy_check" && %w[already_paid_online wants_to_renew declined_renewal].include?(outcome)
      errors.add(:outcome, "belongs in a separate renewal contact")
    end
    if paper_reference.present? && !membership_assignment
      errors.add(:paper_reference, "requires the assignment printed on the call sheet")
    end
    return unless membership_assignment

    drive = membership_assignment.membership_drive
    unless person_id == membership_assignment.person_id && organization_id == drive.organization_id &&
        membership_year == drive.membership_year && purpose == drive.purpose
      errors.add(:membership_assignment, "does not match the member, year, or purpose")
    end
    if paper_reference.present? && !paper_reference.match?(/\A#{drive.id}-#{membership_assignment.id}-[a-f0-9]{12}\z/)
      errors.add(:paper_reference, "must match this assignment's printed reference")
    end
  end
end
