class RosterImport < ApplicationRecord
  STATUSES = %w[completed failed].freeze
  STALE_AFTER = 30.days

  validates :uploaded_filename, :status, :imported_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :created_count, :updated_count, :unchanged_count, :removed_count, :problem_count,
    numericality: { greater_than_or_equal_to: 0 }

  scope :successful, -> { where(status: "completed") }

  def self.latest_successful
    successful.order(imported_at: :desc, id: :desc).first
  end

  def self.roster_stale?
    latest = latest_successful
    latest.blank? || latest.imported_at < STALE_AFTER.ago
  end
end
