module WebsiteCalendarEntry
  extend ActiveSupport::Concern

  LISTINGS = { "default" => "Type default", "show" => "Show", "hide" => "Hide" }.freeze
  ATTENDANCE = { "members" => "Post members", "public" => "Open to the public", "invited" => "Invited participants" }.freeze
  FIELDS = %w[website_listing website_title website_description attendance].freeze
  AUDITED_FIELDS = (FIELDS + %w[calendar_category title starts_at ends_at all_day cancelled location location_name location_address]).freeze

  included do
    attr_accessor :website_calendar_actor
    before_validation -> { self.website_public_id ||= SecureRandom.hex(16) }
    normalizes :website_title, :website_description, with: ->(value) { value&.strip.presence }
    validates :website_listing, inclusion: { in: LISTINGS.keys }
    validates :attendance, inclusion: { in: ATTENDANCE.keys }
    validates :website_title, length: { maximum: 200 }
    validates :website_description, length: { maximum: 10_000 }
    validate :website_identity_is_permanent
    after_save :audit_website_calendar_save
    after_destroy :audit_website_calendar_destroy
  end

  def website_listed?(types: organization.website_calendar_types)
    website_listing == "show" || (website_listing == "default" && calendar_category.present? && types.include?(calendar_category))
  end

  def website_calendar_payload
    zone = organization.calendar_time_zone
    start = starts_at.in_time_zone(zone)
    date_only = is_a?(CalendarEvent) && all_day?
    finish = is_a?(CalendarEvent) ? ends_at&.in_time_zone(zone) : nil
    place = is_a?(CalendarEvent) ? location : [ location_name, location_address ].compact_blank.join(", ")
    {
      "id" => website_public_id, "title" => website_title.presence || title,
      "description" => [ "Attendance: #{ATTENDANCE.fetch(attendance)}.", website_description.presence ].compact.join("\n\n"),
      "location" => place.presence, "category" => "public_event", "attendance" => attendance,
      "all_day" => date_only, "cancelled" => cancelled?,
      "starts_at" => date_only ? nil : start.iso8601, "ends_at" => date_only ? nil : finish&.iso8601,
      "starts_on" => date_only ? start.to_date.iso8601 : nil,
      "ends_on_exclusive" => date_only && finish ? (finish.to_date + 1).iso8601 : nil,
      "updated_at" => [ updated_at, organization.updated_at ].max.utc.iso8601(6)
    }
  end

  def website_calendar_state
    attributes.slice(*FIELDS).merge("enabled" => organization.website_calendar_enabled?,
      "listed" => organization.website_calendar_enabled? && website_listed?,
      "type_default" => organization.website_calendar_types.include?(calendar_category))
  end

  private

  def website_identity_is_permanent
    errors.add(:website_public_id, "cannot change") if persisted? && will_save_change_to_website_public_id?
  end

  def website_audit_actor
    website_calendar_actor || Current.session&.user || (updated_by if is_a?(CalendarEvent))
  end

  def audit_website_calendar_save
    changes = saved_changes.slice(*AUDITED_FIELDS)
    return if changes.empty?

    WebsiteCalendarChange.record!(self, action: "saved", details: { "changes" => changes }, actor: website_audit_actor)
  end

  def audit_website_calendar_destroy
    WebsiteCalendarChange.record!(self, action: "deleted", details: { "public_id" => website_public_id }, actor: website_audit_actor)
  end
end
