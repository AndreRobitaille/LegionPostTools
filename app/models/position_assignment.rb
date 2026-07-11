class PositionAssignment < ApplicationRecord
  belongs_to :person
  belongs_to :position_title

  validates :starts_on, presence: true
  validate :ends_on_must_not_precede_starts_on

  def active_on?(date)
    starts_on <= date && (ends_on.blank? || ends_on >= date)
  end

  private

  def ends_on_must_not_precede_starts_on
    return if ends_on.blank? || starts_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, "must be on or after starts on")
  end
end
