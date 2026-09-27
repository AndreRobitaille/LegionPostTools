class WebsitePublication < ApplicationRecord
  INTERNAL_CATEGORIES = %w[member_meeting officer_meeting planning_meeting honor_guard].freeze
  STORY_FIELDS = %w[display_name introduction story conversation_starter portrait_alt].freeze
  EVENT_FIELDS = %w[title description].freeze
  class Conflict < StandardError; end
  class Forbidden < StandardError; end

  belongs_to :organization
  belongs_to :calendar_event, optional: true
  has_many :portraits, class_name: "WebsitePortrait", dependent: :restrict_with_exception
  has_many :publication_events, class_name: "WebsitePublicationEvent", dependent: :restrict_with_exception
  before_validation -> { self.public_id ||= SecureRandom.hex(16) }
  validates :kind, inclusion: { in: %w[story event] }
  validates :status, inclusion: { in: %w[draft published withdrawn] }
  validates :public_id, presence: true, uniqueness: true
  validate :source_identity_is_permanent
  scope :published, -> { where(status: "published") }

  def story? = kind == "story"
  def published? = status == "published"

  def self.create_draft!(organization:, actor:, calendar_event: nil)
    WebsitePublishing::Boundary.synchronize(organization.id) do
      authorize!(actor)
      if calendar_event
        calendar_event.reload
        raise ArgumentError, "Choose an event from this Post." unless calendar_event.organization_id == organization.id
      end
      raise Conflict, "This calendar event already has a publication. Reload the workspace." if calendar_event && exists?(calendar_event_id: calendar_event.id)
      create!(organization: organization, calendar_event: calendar_event,
        original_calendar_event_id: calendar_event&.id, kind: calendar_event ? "event" : "story",
        draft: calendar_event ? { title: calendar_event.title, description: calendar_event.description } : {}).tap do |publication|
        publication.record!("created", actor)
      end
    end
  end

  def self.authorize!(actor)
    raise Forbidden, "Publishing permission is required." unless actor && actor.reload.disabled_at.nil? && actor.can?("publish_public_content")
  end

  def edit_draft!(actor:, version:, attributes:, portrait: nil)
    # Decode before the lock; expensive uploads never hold the editorial boundary.
    raise ArgumentError, "Portraits belong to introductions." if portrait && !story?
    renditions = WebsitePortrait.prepare(portrait) if portrait
    mutate!(actor: actor, version: version) do
      values = attributes.stringify_keys.slice(*(story? ? STORY_FIELDS : EVENT_FIELDS))
      raise ArgumentError, "Keep each text field under 20,000 characters." if values.values.any? { |value| !value.is_a?(String) || value.length > 20_000 }
      self.draft = draft.merge(values.transform_values { |value| value.strip.presence })
      if renditions
        image = portraits.create!(**renditions)
        self.draft = draft.merge("portrait_revision" => image.revision)
      end
      save!
      record!("draft_saved", actor)
    end
  end

  def confirm_consent!(actor:, version:, note:)
    mutate!(actor: actor, version: version) do
      raise ArgumentError, "Record how consent covers this text and portrait." unless story? && note.is_a?(String) && note.strip.present? && note.length <= 2000
      update!(consent: true, consent_note: note, draft: draft.merge("consent_draft" => consent_fingerprint))
      record!("consent_confirmed", actor, note: note)
    end
  end

  def consent_covers_draft?
    consent && draft["consent_draft"] == consent_fingerprint
  end

  def withdraw!(actor:, version:, revoke_consent: false)
    mutate!(actor: actor, version: version, restrictive: true) do
      self.consent = false if revoke_consent
      restrict!(revoke_consent ? "consent_revoked" : "withdrawn", actor)
    end
  end

  def approve_eligibility!(actor:, version:, source_version:, reason:, resolve_flags: false)
    raise Conflict, "Review the source version before approving eligibility." if source_version.nil?
    mutate!(actor: actor, version: version, source_version: source_version) do
      source = calendar_event
      raise ArgumentError, "The event must be public and have no stored internal category." unless source.public? && !INTERNAL_CATEGORIES.include?(source.calendar_category)
      raise ArgumentError, "Explain why this is an activity for the public." unless reason.is_a?(String) && reason.strip.present? && reason.length <= 2000
      raise ArgumentError, "Resolve the title warning explicitly before approval." if title_flag.present? && !resolve_flags
      source.update!(website_designation: "public_eligible", updated_by: actor)
      update!(eligibility_reason: reason, eligibility_source_version: source.lock_version)
      record!("eligibility_approved", actor, reason: reason, title_flag: title_flag, source_version: source.lock_version)
    end
  end

  def mark_internal!(actor:, version:, source_version:)
    mutate!(actor: actor, version: version, source_version: source_version) do
      calendar_event.update!(website_designation: "internal", updated_by: actor)
      reload
    end
  end

  def title_flag
    return unless calendar_event
    candidate = calendar_event.dup
    candidate.calendar_category = nil
    category = CalendarCategories.for(candidate)
    category if INTERNAL_CATEGORIES.include?(category)
  end

  def publish!(actor:, version:, source_version: nil)
    raise Conflict, "Review the source version before publishing." if !story? && source_version.nil?
    mutate!(actor: actor, version: version, source_version: source_version) do
      if story?
        raise ArgumentError, "Confirm consent for this exact text and portrait before publishing." unless consent_covers_draft?
        %w[display_name introduction story portrait_alt portrait_revision].each { |field| raise ArgumentError, "Complete #{field.humanize.downcase}." if draft[field].blank? }
        portraits.find_by!(revision: draft["portrait_revision"])
        body = draft.slice(*STORY_FIELDS, "portrait_revision")
      else
        raise ArgumentError, "Review eligibility before publishing." unless calendar_event.public? && calendar_event.website_designation == "public_eligible" && !INTERNAL_CATEGORIES.include?(calendar_event.calendar_category)
        raise ArgumentError, "Review the current title warning before publishing." if title_flag.present? && eligibility_source_version != calendar_event.lock_version
        raise ArgumentError, "Complete the public title." if draft["title"].blank?
        body = draft.slice(*EVENT_FIELDS).merge(source_fields)
        self.published_source_version = calendar_event.lock_version
      end
      self.snapshot = body.merge("id" => public_id, "updated_at" => Time.current.utc.iso8601(6))
      self.status = "published"
      save!
      record!("published", actor, snapshot: snapshot, source_version: published_source_version)
    end
  end

  def source_fields
    source = calendar_event
    zone = organization.calendar_time_zone
    start = source.starts_at.in_time_zone(zone)
    finish = source.ends_at&.in_time_zone(zone)
    { "location" => source.location.presence, "all_day" => source.all_day?, "cancelled" => source.cancelled?,
      "starts_at" => source.all_day? ? nil : start.iso8601, "ends_at" => source.all_day? ? nil : finish&.iso8601,
      "starts_on" => source.all_day? ? start.to_date.iso8601 : nil,
      "ends_on_exclusive" => source.all_day? && finish ? (finish.to_date + 1).iso8601 : nil, "category" => "public_event" }
  end

  def pending_source_changes?
    !story? && published? && calendar_event.present? && published_source_version != calendar_event.lock_version
  end

  # Called inside the same boundary and transaction as every supported source save.
  def restrict!(action, actor, details = {})
    self.status = "withdrawn"
    self.featured_position = nil
    self.updated_at = Time.current
    updated_at_will_change!
    save!
    record!(action, actor, details)
  end

  def cancel_from_source!(actor)
    self.snapshot = snapshot.merge("cancelled" => true, "updated_at" => Time.current.utc.iso8601(6)) if published?
    self.updated_at = Time.current
    updated_at_will_change!
    save!
    record!("source_cancelled", actor)
  end

  def record!(action, actor, details = {})
    token = Current.agent_access_token
    if token && token.user_id == actor&.id
      details = details.merge(delegated_agent: { token_id: token.id, name: token.name })
    end
    publication_events.create!(action: action, actor_id: actor&.id, version: lock_version, details: details)
  end

  def self.feature!(organization:, actor:, ids:, versions:)
    WebsitePublishing::Boundary.synchronize(organization.id) do
      authorize!(actor)
      ids = ids.reject(&:blank?)
      raise ArgumentError, "Choose up to three different published introductions." unless ids.size <= 3 && ids.uniq == ids
      scope = where(organization: organization, kind: "story")
      # Include current order and every candidate version in the reviewed form.
      current_versions = scope.order(:id).pluck(:id, :lock_version).to_h.transform_keys(&:to_s).transform_values(&:to_s)
      raise Conflict, "Introductions changed. Review the selection again." unless versions.to_h == current_versions
      selected = ids.map { |id| scope.published.find_by!(public_id: id) }
      scope.where.not(featured_position: nil).each { |record| record.update!(featured_position: nil) }
      selected.each_with_index { |record, index| record.reload.update!(featured_position: index + 1) }
      scope.each { |record| record.record!("featured_order", actor, public_ids: ids) }
    end
  end

  private

  def consent_fingerprint
    Digest::SHA256.hexdigest(draft.except("consent_draft").to_json)
  end

  def mutate!(actor:, version:, source_version: nil, restrictive: false)
    WebsitePublishing::Boundary.synchronize(organization_id) do
      self.class.authorize!(actor)
      reload
      valid_version = version.to_s.match?(/\A\d+\z/) && (restrictive ? version.to_i <= lock_version : version.to_i == lock_version)
      raise Conflict, "This review is out of date. Review the latest version." unless valid_version
      unless story? || restrictive
        raise ArgumentError, "The original calendar event is no longer available." unless calendar_event && calendar_event.organization_id == organization_id
        if source_version && (!source_version.to_s.match?(/\A\d+\z/) || calendar_event.lock_version != source_version.to_i)
          raise Conflict, "The calendar event changed. Review its current schedule and location."
        end
      end
      yield
    end
  end

  def source_identity_is_permanent
    if persisted? && (will_save_change_to_kind? || will_save_change_to_organization_id? || will_save_change_to_public_id? || will_save_change_to_original_calendar_event_id? || (will_save_change_to_calendar_event_id? && calendar_event_id.present?))
      errors.add(:base, "Publication identity and original source cannot change")
    end
    if kind == "event" && new_record? && (!calendar_event || calendar_event.organization_id != organization_id)
      errors.add(:calendar_event, "must belong to this Post")
    end
  end
end
