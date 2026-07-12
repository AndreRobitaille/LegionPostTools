class RosterImport < ApplicationRecord
  STATUSES = %w[completed failed pending_confirmation].freeze
  STALE_AFTER = 30.days

  has_one_attached :pending_csv

  validates :uploaded_filename, :status, :imported_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :created_count, :updated_count, :unchanged_count, :removed_count, :problem_count,
    numericality: { greater_than_or_equal_to: 0 }
  validate :pending_csv_attached_when_pending_confirmation

  scope :successful, -> { where(status: "completed") }
  scope :history, -> { order(imported_at: :desc, id: :desc) }

  def self.latest_successful
    successful.order(imported_at: :desc, id: :desc).first
  end

  def self.roster_stale?
    latest = latest_successful
    latest.blank? || latest.imported_at < STALE_AFTER.ago
  end

  def problems
    Array(summary&.fetch("problems", nil))
  end

  def removed_members
    Array(summary&.fetch("removed_members", nil))
  end

  def access_effects
    summary&.fetch("access_effects", {}) || {}
  end

  def sign_in_exceptions
    User.where(login_access_override: true).includes(:person).order("people.last_name", "people.first_name")
  end

  private

  def pending_csv_attached_when_pending_confirmation
    return unless status == "pending_confirmation"
    return if pending_csv.attached?

    errors.add(:pending_csv, "must be attached")
  end
end
