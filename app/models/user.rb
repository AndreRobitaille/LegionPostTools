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

  ROSTER_LOGIN_ENABLED_STATUSES = %w[active grace].freeze
  ROSTER_LOGIN_DISABLED_STATUSES = %w[expired deceased].freeze

  def apply_roster_access!
    transaction do
      lock_relevant_admin_rows! if roster_access_should_disable?

      return :skipped_admin_override if login_access_override?

      apply_roster_access_without_override_check!
    end
  end

  def return_to_roster_control!
    transaction do
      lock_relevant_admin_rows! if roster_access_should_disable?

      return :skipped_last_admin if roster_access_should_disable? && only_enabled_administrator?

      update!(login_access_override: false, login_access_override_at: nil)
      apply_roster_access_without_override_check!
    end
  end

  def set_login_access_override!(disabled:)
    transaction do
      lock_relevant_admin_rows! if disabled && can?("manage_settings")

      if disabled && only_enabled_administrator?
        return :skipped_last_admin
      end

      update!(disabled_at: (disabled ? Time.current : nil), login_access_override: true, login_access_override_at: Time.current)
    end
  end

  def roster_access_status
    return "removed" if person.roster_removed_at.present?

    person.roster_member_status.to_s.strip.downcase
  end

  def roster_access_should_enable?
    ROSTER_LOGIN_ENABLED_STATUSES.include?(roster_access_status)
  end

  def roster_access_should_disable?
    roster_access_status == "removed" || ROSTER_LOGIN_DISABLED_STATUSES.include?(roster_access_status)
  end

  def roster_access_unsupported_status?
    !roster_access_should_enable? && !roster_access_should_disable?
  end

  private

  def apply_roster_access_without_override_check!
    return :unsupported_status if roster_access_unsupported_status?

    if roster_access_should_enable?
      update!(disabled_at: nil) if disabled_at.present?
      :enabled_by_roster_status
    elsif only_enabled_administrator?
      :skipped_last_admin
    else
      update!(disabled_at: Time.current) if disabled_at.blank?
      :disabled_by_roster_status
    end
  end

  def lock_relevant_admin_rows!
    self.class.where(disabled_at: nil)
      .joins(:permission_grants)
      .where(permission_grants: { capability: "manage_settings" })
      .lock
      .load
    lock!
  end

  # WebAuthn requires an opaque, non-PII, base64url user handle (not the DB id).
  def assign_webauthn_id
    self.webauthn_id ||= WebAuthn.generate_user_id
  end
end
