class MinutesDistributionSetting < ApplicationRecord
  belongs_to :organization

  normalizes :post_members_list_id, :minutes_recipients_list_id, :template_id, :reply_to,
    with: ->(value) { value.to_s.strip.presence }
  validates :organization_id, uniqueness: true
  validates :reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validate :distinct_lists
  validate :selected_meeting_types_belong_to_organization
  validate :enabled_configuration
  validate :list_changes_need_review

  def groups_configured?
    post_members_list_id.present? && minutes_recipients_list_id.present? &&
      post_members_list_id != minutes_recipients_list_id
  end

  def includes_minutes?(minutes)
    enabled? && meeting_type_ids.include?(minutes.meeting_type_id)
  end

  private

  def distinct_lists
    errors.add(:minutes_recipients_list_id, "must differ from Post members") if
      post_members_list_id.present? && post_members_list_id == minutes_recipients_list_id
  end

  def selected_meeting_types_belong_to_organization
    return if meeting_type_ids.is_a?(Array) &&
      meeting_type_ids.all? { |id| id.is_a?(Integer) } &&
      organization.meeting_types.where(id: meeting_type_ids).count == meeting_type_ids.uniq.size

    errors.add(:meeting_type_ids, "must identify this Post's meeting types")
  end

  def enabled_configuration
    return unless enabled?
    return if groups_configured? && audiences_reviewed? && template_id.present? &&
      reply_to.present? && meeting_type_ids.any?

    errors.add(:base, "Complete the groups, campaign review, template, reply address and meeting types before enabling automatic email.")
  end

  def list_changes_need_review
    return unless persisted? && (will_save_change_to_post_members_list_id? || will_save_change_to_minutes_recipients_list_id?)
    return unless organization.minutes_distributions.exists? || organization.minutes_recipients.where.not(loops_contact_id: nil).exists? ||
      organization.loops_roster_enrollments.exists?

    errors.add(:base, "These groups have recorded enrollments or mailings. Group migration requires an operator review.")
  end
end
