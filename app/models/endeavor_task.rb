class EndeavorTask < ApplicationRecord
  belongs_to :endeavor
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :completed_by, class_name: "User", optional: true

  validates :title, presence: true, length: { maximum: 200 }
  validate :completion_provenance

  scope :open, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :ordered, -> { order(Arel.sql("due_on ASC NULLS LAST"), :created_at, :id) }

  def completed? = completed_at.present?

  def set_completion(completed, user:)
    return if completed == completed?

    self.completed_at = completed ? Time.current : nil
    self.completed_by = completed ? user : nil
  end

  private

  def completion_provenance
    if completed_at.present? != completed_by.present?
      errors.add(:base, "Completion must record both who completed the step and when.")
    end
  end
end
