class MembershipDuesRecord < ApplicationRecord
  include ImmutableMembershipEntry

  KINDS = {
    "post_receipt" => "Full-year dues received by the Post",
    "national_reported" => "Member reports paying National",
    "post_share_received" => "Post-share check received",
    "reversal" => "Correction reversing an earlier entry"
  }.freeze

  belongs_to :organization
  belongs_to :person, optional: true
  belongs_to :recorded_by, class_name: "User"
  belongs_to :reverses_record, class_name: "MembershipDuesRecord", optional: true
  has_one :reversal, class_name: "MembershipDuesRecord", foreign_key: :reverses_record_id, dependent: :restrict_with_exception

  validates :membership_year, inclusion: { in: MembershipReport::VALID_YEARS }
  validates :kind, inclusion: { in: KINDS.keys }
  validates :received_on, :submission_key, presence: true
  validates :submission_key, uniqueness: true, length: { maximum: 100 }
  validates :amount, numericality: { greater_than: 0, less_than: 10**10 }, if: -> { %w[post_receipt post_share_received].include?(kind) }
  validates :reference, length: { maximum: 160 }
  validates :notes, length: { maximum: 2000 }
  validates :person, presence: true, if: -> { %w[post_receipt national_reported].include?(kind) }
  validates :reverses_record_id, uniqueness: true, allow_nil: true
  validate :kind_fields_match
  validate :amount_uses_cents

  scope :effective, -> { where.not(kind: "reversal").where.not(id: where(kind: "reversal").select(:reverses_record_id)) }
  scope :recent, -> { order(received_on: :desc, id: :desc) }

  private

  def amount_uses_cents
    return if amount_before_type_cast.blank?

    value = BigDecimal(amount_before_type_cast.to_s, exception: false)
    if value&.finite? && (value * 100).frac.nonzero?
      errors.add(:amount, "must have no more than two decimal places")
    end
  end

  def kind_fields_match
    errors.add(:received_on, "cannot be in the future") if received_on && received_on > Organization.current_local_date
    if kind == "post_share_received" && person_id.present?
      errors.add(:person, "must be blank for a Post-share check; it does not pay an individual member's dues")
    end
    errors.add(:amount, "must be blank for a reported National payment") if kind == "national_reported" && amount.present?
    if kind == "reversal"
      unless reverses_record && reverses_record.kind != "reversal" &&
          reverses_record.organization_id == organization_id && reverses_record.membership_year == membership_year &&
          reverses_record.person_id == person_id && reverses_record.amount == amount
        errors.add(:reverses_record, "must be a matching original entry")
      end
      errors.add(:notes, "must explain the correction") if notes.blank?
    elsif reverses_record_id.present?
      errors.add(:reverses_record, "is only used for corrections")
    end
  end
end
