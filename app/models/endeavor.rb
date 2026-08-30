class Endeavor < ApplicationRecord
  IMPORTANCE_LEVELS = {
    "standard" => "Standard",
    "important" => "Important"
  }.freeze
  STATUSES = {
    "active" => "Active",
    "completed" => "Completed"
  }.freeze
  PRIORITY_BUCKETS = {
    "necessity" => "Important and urgent — Necessity",
    "focus" => "Important, not urgent — Focus",
    "delegate" => "Time-sensitive — Delegate or handle",
    "keep_tracking" => "Keep tracking"
  }.freeze
  URGENT_WITHIN = 30.days

  belongs_to :organization
  belongs_to :meeting_body, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :completed_by, class_name: "User", optional: true

  has_many :updates,
    -> { order(created_at: :desc, id: :desc) },
    class_name: "EndeavorUpdate",
    dependent: :restrict_with_exception,
    inverse_of: :endeavor
  has_many :dated_agenda_items, dependent: :restrict_with_exception
  has_many :dated_agendas, through: :dated_agenda_items
  has_rich_text :details

  before_validation :normalize_optional_fields

  validates :title, :importance, :status, presence: true
  validates :importance, inclusion: { in: IMPORTANCE_LEVELS.keys }
  validates :status, inclusion: { in: STATUSES.keys }
  validate :meeting_body_belongs_to_organization
  validate :completed_provenance_matches_status

  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :recently_completed, -> { completed.order(completed_at: :desc, title: :asc) }

  def active? = status == "active"
  def completed? = status == "completed"
  def important? = importance == "important"

  def urgent?(on: Date.current)
    raise_by_on.present? && raise_by_on <= on + URGENT_WITHIN
  end

  def priority_bucket(on: Date.current)
    return "necessity" if important? && urgent?(on:)
    return "focus" if important?
    return "delegate" if urgent?(on:)

    "keep_tracking"
  end

  def priority_sort_key
    [ raise_by_on || Date.new(9999, 12, 31), title.downcase ]
  end

  def complete!(user)
    with_lock do
      unless active?
        errors.add(:base, "Only active Endeavors can be completed.")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: "completed", completed_by: user, completed_at: Time.current)
    end
  end

  def reopen!
    with_lock do
      unless completed?
        errors.add(:base, "Only completed Endeavors can be reopened.")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: "active", completed_by: nil, completed_at: nil)
    end
  end

  private

  def normalize_optional_fields
    self.summary = summary.to_s.strip
  end

  def meeting_body_belongs_to_organization
    return if meeting_body.blank? || organization.blank?
    return if meeting_body.organization_id == organization_id

    errors.add(:meeting_body, "must belong to the same organization")
  end

  def completed_provenance_matches_status
    if completed?
      errors.add(:completed_by, "must be recorded for a completed item") if completed_by.blank?
      errors.add(:completed_at, "must be recorded for a completed item") if completed_at.blank?
    elsif completed_by.present? || completed_at.present?
      errors.add(:base, "Active Endeavors cannot have completion details")
    end
  end
end
