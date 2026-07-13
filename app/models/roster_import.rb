class RosterImport < ApplicationRecord
  STATUSES = %w[completed failed pending_confirmation discarded].freeze
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

  # The first problem's message, tolerant of older imports whose summary stored problems as
  # plain strings rather than {message:, ...} hashes.
  def first_problem_message
    first = problems.first
    first.is_a?(Hash) ? first["message"] : first
  end

  # Problems as {message:, row:, kind:} hashes, tolerant of older imports (or raw
  # CSV parse failures) whose summary stored problems as plain strings. Display and
  # partition code can then treat every entry uniformly.
  def normalized_problems
    problems.map { |problem| problem.is_a?(Hash) ? problem : { "message" => problem } }
  end

  def access_effects
    summary&.fetch("access_effects", {}) || {}
  end

  def sign_in_exceptions
    User.where(login_access_override: true).includes(:person).order("people.last_name", "people.first_name")
  end

  # A pending import is superseded once any newer import has itself gone pending or completed —
  # confirming the older one would apply a stale CSV over newer roster state.
  def superseded?
    self.class.where("id > ?", id).where(status: %w[pending_confirmation completed]).exists?
  end

  private

  def pending_csv_attached_when_pending_confirmation
    return unless status == "pending_confirmation"
    return if pending_csv.attached?

    errors.add(:pending_csv, "must be attached")
  end
end
