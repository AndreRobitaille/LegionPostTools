class MinutesDistributionSetting < ApplicationRecord
  belongs_to :organization

  normalizes :post_members_list_id, :minutes_recipients_list_id, :template_id, :reply_to,
    with: ->(value) { value.to_s.strip.presence }
  normalizes :email_subject_template, :email_cover_note_template, with: ->(value) { value&.strip }
  validates :organization_id, uniqueness: true
  validates :reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validate :distinct_lists
  validate :selected_meeting_types_belong_to_organization
  validate :enabled_configuration
  validate :list_changes_need_review
  validate :valid_email_wording

  def email_wording
    { "subject" => email_subject_template || MinutesDistribution::EmailTemplate::DEFAULT_SUBJECT,
      "cover_note" => email_cover_note_template || MinutesDistribution::EmailTemplate::DEFAULT_COVER_NOTE }
  end

  def list_connections_in_use?
    persisted? && (organization.minutes_distributions.exists? || organization.minutes_recipients.where.not(loops_contact_id: nil).exists? ||
      organization.loops_roster_enrollments.exists?)
  end

  def groups_configured?
    post_members_list_id.present? && minutes_recipients_list_id.present? &&
      post_members_list_id != minutes_recipients_list_id
  end

  def includes_minutes?(minutes)
    enabled? && meeting_type_ids.include?(minutes.meeting_type_id)
  end

  private

  def valid_email_wording
    email_wording.each do |part, text|
      attribute = part == "subject" ? :email_subject_template : :email_cover_note_template
      errors.add(attribute, "can't be blank") if text.blank?
      errors.add(attribute, "is too long") if text.to_s.length > (part == "subject" ? 500 : 4_000)
      MinutesDistribution::EmailTemplate.problems(text).each { |problem| errors.add(attribute, problem) }
    end
    subject = email_wording.fetch("subject")
    errors.add(:email_subject_template, "must be a single line") if subject.match?(/[\r\n]/)
    unless subject.scan(MinutesDistribution::EmailTemplate::TOKEN).flatten.include?("copy_label")
      errors.add(:email_subject_template, "must include {{copy_label}} so corrected copies are clearly marked")
    end
  end

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

    errors.add(:base, "Choose meetings and an address for replies, complete the Loops connections, and confirm that regular Post email uses Post members before enabling automatic minutes email.")
  end

  def list_changes_need_review
    return unless persisted? && (will_save_change_to_post_members_list_id? || will_save_change_to_minutes_recipients_list_id?)
    return unless list_connections_in_use?

    errors.add(:base, "These groups have recorded enrollments or mailings. Group migration requires an operator review.")
  end
end
