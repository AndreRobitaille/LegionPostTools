class MinutesRecipient < ApplicationRecord
  belongs_to :organization
  normalizes :email, with: ->(value) { value.to_s.strip.downcase }
  normalizes :name, :office, with: ->(value) { value.to_s.strip }
  validates :name, :office, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  scope :active, -> { where(active: true) }

  def snapshot
    attributes.slice("id", "name", "office", "email", "loops_contact_id")
  end
end
