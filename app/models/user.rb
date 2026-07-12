class User < ApplicationRecord
  belongs_to :person
  has_many :permission_grants, dependent: :destroy
  has_many :passkey_credentials, dependent: :destroy

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  before_validation :assign_webauthn_id, on: :create

  validates :email_address, presence: true, uniqueness: true
  validates :person_id, uniqueness: true
  validates :webauthn_id, presence: true, uniqueness: true

  def can?(capability)
    permission_grants.exists?(capability: capability.to_s)
  end

  def roster_email_mismatch?
    person.roster_email_address.present? && person.roster_email_address != email_address
  end

  def needs_roster_email_review?
    return false unless roster_email_mismatch?
    return true if roster_email_review_decision == "remind_later"

    roster_email_reviewed_address != person.roster_email_address
  end

  def keep_current_login_email!
    update!(
      roster_email_reviewed_address: person.roster_email_address,
      roster_email_review_decision: "keep_current",
      roster_email_reviewed_at: Time.current
    )
  end

  def remind_later_about_roster_email!
    update!(
      roster_email_reviewed_address: person.roster_email_address,
      roster_email_review_decision: "remind_later",
      roster_email_reviewed_at: Time.current
    )
  end

  def update_login_email_to_roster_email!
    update!(
      email_address: person.roster_email_address,
      roster_email_reviewed_address: person.roster_email_address,
      roster_email_review_decision: "updated_login",
      roster_email_reviewed_at: Time.current
    )
  end

  def self.another_enabled_manage_settings_user_exists?(user)
    where(disabled_at: nil)
      .where.not(id: user.id)
      .joins(:permission_grants)
      .where(permission_grants: { capability: "manage_settings" })
      .exists?
  end

  def only_enabled_administrator?
    disabled_at.blank? && can?("manage_settings") && !self.class.another_enabled_manage_settings_user_exists?(self)
  end

  private

  # WebAuthn requires an opaque, non-PII, base64url user handle (not the DB id).
  def assign_webauthn_id
    self.webauthn_id ||= WebAuthn.generate_user_id
  end
end
