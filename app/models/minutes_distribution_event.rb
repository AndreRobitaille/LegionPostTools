class MinutesDistributionEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :meeting_minutes, optional: true
  belongs_to :minutes_recipient, optional: true
  belongs_to :actor, class_name: "User"
  validates :action, presence: true

  def readonly? = persisted?

  def self.held?(minutes)
    where(meeting_minutes: minutes, action: %w[hold release]).order(id: :desc).first&.action == "hold"
  end
end
