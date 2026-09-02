class OfficialActionConfirmation < ApplicationRecord
  ACTIONS = %w[approve attest reopen record_membership_approval].freeze
  METHODS = %w[in_app delegated_agent external_written_confirmation].freeze
  TTL = 10.minutes

  belongs_to :user
  belongs_to :session, optional: true
  belongs_to :agent_access_token, optional: true
  belongs_to :meeting_minutes

  validates :action, inclusion: { in: ACTIONS }
  validates :confirmation_method, inclusion: { in: METHODS }
  validates :record_lock_version, :content_digest, :expires_at, presence: true
  validates :session, presence: true, if: -> { in_app? && agent_access_token.blank? }
  validates :evidence_note, presence: true, if: :external_written_confirmation?
  validate :session_belongs_to_user

  def self.prepare!(minutes:, user:, session:, action:, action_payload: {})
    action_payload = action_payload.to_h.deep_stringify_keys
    create!(
      user:,
      session:,
      meeting_minutes: minutes,
      action:,
      record_lock_version: minutes.lock_version,
      content_digest: minutes.digest_for(action, payload: action_payload),
      action_payload:,
      confirmation_method: "in_app",
      expires_at: TTL.from_now
    )
  end

  def self.for_delegated_agent!(minutes:, agent_access_token:, action:, action_payload: {})
    action_payload = action_payload.to_h.deep_stringify_keys
    create!(
      user: agent_access_token.user,
      agent_access_token:,
      meeting_minutes: minutes,
      action:,
      record_lock_version: minutes.lock_version,
      content_digest: minutes.digest_for(action, payload: action_payload),
      action_payload:,
      confirmation_method: "delegated_agent",
      expires_at: TTL.from_now,
      confirmed_at: Time.current
    )
  end

  def self.record_external!(minutes:, user:, action:, evidence_note:, action_payload: {})
    action_payload = action_payload.to_h.deep_stringify_keys
    create!(
      user:,
      meeting_minutes: minutes,
      action:,
      record_lock_version: minutes.lock_version,
      content_digest: minutes.digest_for(action, payload: action_payload),
      action_payload:,
      confirmation_method: "external_written_confirmation",
      evidence_note:,
      expires_at: TTL.from_now,
      confirmed_at: Time.current
    )
  end

  def confirm!(session:)
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless usable_by?(user:, session:)

      update!(confirmed_at: Time.current)
    end
  end

  def consume!(user:, session: nil)
    with_lock do
      unless usable_by?(user:, session:) && confirmed_at.present?
        errors.add(:base, "This confirmation is invalid or expired.")
        raise ActiveRecord::RecordInvalid, self
      end

      yield
      update!(consumed_at: Time.current)
    end
  end

  def usable_by?(user:, session: nil)
    return false if consumed_at.present? || expires_at.past? || self.user != user
    return true if external_written_confirmation? || delegated_agent?

    self.session == session
  end

  def in_app? = confirmation_method == "in_app"
  def delegated_agent? = confirmation_method == "delegated_agent"
  def external_written_confirmation? = confirmation_method == "external_written_confirmation"

  private

  def session_belongs_to_user
    return if session.blank? || session.user == user

    errors.add(:session, "must belong to the same user")
  end
end
