class User < ApplicationRecord
  DISABLED_REASONS = %w[manual roster_status roster_removed].freeze
  ROSTER_LOGIN_ENABLED_STATUSES = %w[active grace].freeze
  ROSTER_LOGIN_DISABLED_STATUSES = %w[expired deceased].freeze
  ADMIN_AREA_CAPABILITIES = %w[
    manage_settings
    manage_agendas
    manage_minutes
    view_internal_records
  ].freeze

  belongs_to :person
  has_many :permission_grants, dependent: :destroy
  has_many :passkey_credentials, dependent: :destroy
  has_many :created_meeting_transcripts,
    class_name: "MeetingTranscript",
    foreign_key: :created_by_id,
    dependent: :restrict_with_exception,
    inverse_of: :created_by
  has_many :purged_meeting_transcripts,
    class_name: "MeetingTranscript",
    foreign_key: :purged_by_id,
    dependent: :restrict_with_exception,
    inverse_of: :purged_by
  has_many :requested_minutes_draft_runs,
    class_name: "MinutesDraftRun",
    foreign_key: :requested_by_id,
    dependent: :restrict_with_exception,
    inverse_of: :requested_by
  has_many :discarded_minutes_draft_runs,
    class_name: "MinutesDraftRun",
    foreign_key: :discarded_by_id,
    dependent: :nullify,
    inverse_of: :discarded_by
  has_many :agent_access_tokens, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :official_action_confirmations, dependent: :restrict_with_exception

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  before_validation :assign_webauthn_id, on: :create

  validates :email_address, presence: true, uniqueness: true
  validates :person_id, uniqueness: true
  validates :webauthn_id, presence: true, uniqueness: true
  validates :disabled_reason, inclusion: { in: DISABLED_REASONS }, allow_nil: true

  def can?(capability)
    capability = capability.to_s
    return true if permission_grants.exists?(capability: capability)
    return true if position_capability_sources.key?(capability)
    return false unless PermissionGrant::IMPLIED_BY_MANAGE_SETTINGS.include?(capability)

    permission_grants.exists?(capability: "manage_settings")
  end

  def can_any?(*capabilities)
    capabilities.any? { |capability| can?(capability) }
  end

  def position_capability_sources(on: Date.current)
    PositionCapabilityGrant
      .joins(position_title: :position_assignments)
      .where(position_assignments: { person_id: person_id })
      .where(position_titles: { active: true })
      .where("position_assignments.starts_on <= ?", on)
      .where("position_assignments.ends_on IS NULL OR position_assignments.ends_on >= ?", on)
      .order("position_titles.display_order", "position_titles.name")
      .pluck(:capability, "position_titles.name")
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(capability, title_name), sources|
        sources[capability] << title_name
      end
  end

  def full_membership_access?(on: Date.current)
    return true if can?("manage_people")

    person.position_assignments
      .joins(:position_title)
      .where(position_titles: { active: true, grants_full_membership_access: true })
      .where("position_assignments.starts_on <= ?", on)
      .where("position_assignments.ends_on IS NULL OR position_assignments.ends_on >= ?", on)
      .exists?
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

  def apply_roster_access!
    transaction do
      lock_relevant_admin_rows! if roster_access_should_disable?

      return :skipped_manual_disable if manually_disabled?

      apply_roster_access_without_override_check!
    end
  end

  def return_to_roster_control!
    transaction do
      return :not_roster_managed unless roster_managed?

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

      update!(
        disabled_at: (disabled ? Time.current : nil),
        disabled_reason: (disabled ? "manual" : nil),
        disabled_reason_detail: nil,
        login_access_override: true,
        login_access_override_at: Time.current
      )
    end
  end

  def roster_managed?
    person.roster_backed?
  end

  def manually_disabled?
    login_access_override? && disabled_at.present?
  end

  def roster_access_status
    return "removed" if person.roster_removed_at.present?

    person.roster_member_status.to_s.strip.downcase
  end

  def roster_access_should_enable?
    ROSTER_LOGIN_ENABLED_STATUSES.include?(roster_access_status)
  end

  def roster_access_should_disable?
    roster_access_status == "removed" || (roster_managed? && !roster_access_should_enable?)
  end

  def roster_access_unsupported_status?
    roster_managed? && roster_access_status != "removed" &&
      !roster_access_should_enable? && !ROSTER_LOGIN_DISABLED_STATUSES.include?(roster_access_status)
  end

  private

  def apply_roster_access_without_override_check!
    if roster_access_should_enable?
      update!(
        disabled_at: nil,
        disabled_reason: nil,
        disabled_reason_detail: nil,
        login_access_override: false,
        login_access_override_at: nil
      ) if disabled_at.present? || disabled_reason.present? || login_access_override?
      :enabled_by_roster_status
    elsif only_enabled_administrator?
      :skipped_last_admin
    else
      reason, detail = roster_disable_reason
      update!(
        disabled_at: disabled_at || Time.current,
        disabled_reason: reason,
        disabled_reason_detail: detail,
        login_access_override: false,
        login_access_override_at: nil
      )
      :disabled_by_roster_status
    end
  end

  def roster_disable_reason
    return [ "roster_removed", nil ] if roster_access_status == "removed"

    [ "roster_status", roster_access_status.presence || "not active" ]
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
