module WebsitePublishing
  class Feed
    def initialize(organization, origin:)
      @organization = organization
      @origin = origin
    end

    def timezone = @organization.calendar_time_zone.tzinfo.identifier

    def featured
      { schema_version: 1, complete: true, members: scope.where(kind: "story").where.not(featured_position: nil).order(:featured_position).map { |record| story(record) } }
    end

    def story_detail(id)
      { schema_version: 1, member: story(scope.find_by!(kind: "story", public_id: id)) }
    end

    def event_detail(id)
      if @organization.website_calendar_enabled?
        record = @organization.calendar_events.find_by(website_public_id: id) || @organization.meetings.find_by(website_public_id: id)
        raise ActiveRecord::RecordNotFound unless record&.website_listed?
        return { schema_version: 1, timezone: timezone, event: record.website_calendar_payload }
      end
      { schema_version: 1, timezone: timezone, event: scope.find_by!(kind: "event", public_id: id).snapshot }
    end

    def events(from:, to:)
      first, last = [ from, to ].map do |value|
        raise ArgumentError unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        Date.iso8601(value)
      end
      raise ArgumentError unless (last - first).between?(1, 93)
      lower, upper = [ first, last ].map { |date| midnight(date) }
      candidates = if @organization.website_calendar_enabled?
        events = @organization.calendar_events.overlapping(lower, upper)
        meetings = @organization.meetings.where(starts_at: lower...upper)
        (events.to_a + meetings.to_a).select(&:website_listed?).map(&:website_calendar_payload)
      else
        scope.where(kind: "event").map(&:snapshot)
      end
      records = candidates.select do |record|
        start, finish = span(record)
        start < upper && (finish > start ? finish > lower : start >= lower)
      end.sort_by { |record| [ span(record).first, record.fetch("id") ] }
      { schema_version: 1, complete: true, timezone: timezone, from: from, to: to, events: records }
    end

    def portrait(id:, revision:, size:)
      raise ActiveRecord::RecordNotFound unless %w[small large].include?(size)
      record = scope.find_by!(kind: "story", public_id: id)
      raise ActiveRecord::RecordNotFound unless record.snapshot["portrait_revision"] == revision
      record.portraits.find_by!(revision: revision).public_send(size)
    end

    private

    def scope
      WebsitePublication.published.where(organization: @organization)
    end

    def story(record)
      snapshot = record.snapshot
      snapshot.slice("id", "display_name", "introduction", "story", "updated_at").merge(
        "conversation_starter" => snapshot["conversation_starter"],
        "portrait" => { revision: snapshot.fetch("portrait_revision"), alt: snapshot.fetch("portrait_alt"), variants: [ [ "small", 320, 400 ], [ "large", 640, 800 ] ].map do |size, width, height|
          { size: size, width: width, height: height, content_type: "image/webp", url: "#{@origin}/public/v1/member_stories/#{record.public_id}/portrait/#{snapshot.fetch('portrait_revision')}/#{size}.webp" }
        end })
    end

    def midnight(date)
      @organization.calendar_time_zone.local(date.year, date.month, date.day)
    end

    def span(record)
      if record.fetch("all_day")
        first = Date.iso8601(record.fetch("starts_on"))
        last = record["ends_on_exclusive"] ? Date.iso8601(record["ends_on_exclusive"]) : first + 1
        [ midnight(first), midnight(last) ]
      else
        first = Time.iso8601(record.fetch("starts_at"))
        [ first, record["ends_at"] ? Time.iso8601(record["ends_at"]) : first ]
      end
    end
  end
end
