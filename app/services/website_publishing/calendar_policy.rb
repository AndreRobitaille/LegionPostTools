module WebsitePublishing
  class CalendarPolicy
    class Conflict < StandardError; end

    def initialize(organization)
      @organization = organization
    end

    def entries
      (@organization.calendar_events.to_a + @organization.meetings.to_a).sort_by { |entry| [ entry.starts_at, entry.class.name, entry.id ] }
    end

    def preview(types:)
      validate_types!(types)
      Boundary.synchronize(@organization.id) do
        @organization.reload
        records = entries
        { types: types, enabled: @organization.website_calendar_enabled?,
          entries: records.map { |entry| { type: entry.class.name, id: entry.id, title: entry.website_title.presence || entry.title,
            starts_at: entry.starts_at, category: entry.calendar_category, listing: entry.website_listing,
            listed: entry.website_listed?(types: types), public_event: entry.website_calendar_payload } },
          review_token: verifier.generate(review_state(types, records), expires_in: 30.minutes) }
      end
    end

    def apply!(actor:, review_token:)
      Boundary.synchronize(@organization.id) do
        WebsitePublication.authorize!(actor)
        @organization.reload
        reviewed = verifier.verified(review_token) if review_token.is_a?(String)
        raise Conflict, "The preview expired or changed. Review the defaults again." unless reviewed.is_a?(Hash)
        types = reviewed["types"]
        validate_types!(types)
        unless reviewed == review_state(types, entries)
          raise Conflict, "Calendar records or defaults changed. Review the latest preview."
        end
        before = @organization.attributes.slice("website_calendar_enabled", "website_calendar_types", "website_calendar_version")
        @organization.update!(website_calendar_enabled: true, website_calendar_types: types,
          website_calendar_version: @organization.website_calendar_version + 1)
        WebsiteCalendarChange.record!(@organization, action: "defaults_saved", actor: actor,
          details: { "before" => before, "types" => types, "version" => @organization.website_calendar_version })
      end
    end

    private

    def validate_types!(types)
      unless types.is_a?(Array) && types.all? { |type| type.is_a?(String) } && (types - CalendarCategories::EDITABLE.keys).empty? && types.uniq == types
        raise ArgumentError, "Choose valid calendar event types."
      end
    end

    def verifier = Rails.application.message_verifier("website-calendar-policy")

    def review_state(types, records)
      { "organization_id" => @organization.id, "version" => @organization.website_calendar_version, "timezone" => @organization.timezone,
        "types" => types, "sources" => Digest::SHA256.hexdigest(records.map { |entry| [ entry.class.name, entry.id, entry.lock_version, entry.updated_at.iso8601(6) ] }.to_json) }
    end
  end
end
