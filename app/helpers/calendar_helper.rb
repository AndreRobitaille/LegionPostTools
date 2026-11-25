module CalendarHelper
  UNKNOWN_PLACE = /
    \b(?:t\.?b\.?[dac]|(?:to\ be|will\ be)\ (?:determined|confirmed|announced|decided|advised)|
         not\ (?:yet\ )?(?:recorded|set|known|confirmed|specified)|unknown|undecided|pending)\b |
    \A(?:n\/?a|none|not\ applicable|[-?–—]+)\z
  /ix
  ONLINE_PLACE = %r{
    https?://|www\.|@|\b(?:online|virtual|zoom|webex|skype|webinar|teleconference|conference\ call|
    phone\ (?:call|only)|(?:by|via)\ phone|dial[-\ ]in|google\ meet|teams\ meeting|(?:microsoft|ms)\ teams|
    meet\.google\.com|teams\.live\.com)\b|\Ateams\z
  }ix

  # A desktop-class iPad can send exactly the same request as a Mac.
  # In that case let the browser choose the visible controls using touch support.
  def calendar_link_devices
    agent = request.user_agent.to_s
    platform = request.headers["Sec-CH-UA-Platform"]
    return [ :android ] if agent.match?(/\bAndroid\b/i) || platform == '"Android"'
    return [ :ios ] if agent.match?(/\bi(?:Phone|Pad|Pod)\b|Macintosh.*\bMobile\//i) || platform == '"iOS"'
    return [ :mac, :ipad ] if agent.include?("Macintosh") || platform == '"macOS"'

    [ :desktop ]
  end

  def calendar_map_query(entry)
    place = calendar_entry_location(entry).to_s.squish
    address = entry.location_address.to_s.squish if entry.is_a?(Meeting)
    return if place.match?(UNKNOWN_PLACE) || place.match?(ONLINE_PLACE) || address&.match?(ONLINE_PLACE)

    query = address.present? && !address.match?(UNKNOWN_PLACE) ? address : place
    return if query.blank?

    ERB::Util.url_encode(query)
  end

  def calendar_map_url(query, device)
    case device
    when :android then "geo:0,0?q=#{query}"
    when :ios, :ipad then "https://maps.apple.com/?q=#{query}"
    else "https://www.google.com/maps/search/?api=1&query=#{query}"
    end
  end

  def calendar_entry_title(entry)
    return member_meeting_title(entry) if entry.is_a?(Meeting)

    entry.title
  end

  def calendar_filter_labels
    CalendarCategories::LABELS.except(*(@month.view == "deadlines" ? [] : [ "deadline" ]))
  end

  def calendar_entry_hidden?(entry)
    !@month.categories.include?(CalendarCategories.for(entry))
  end

  def calendar_print_description_parts(entry)
    return [ nil, nil ] unless entry.is_a?(CalendarEvent) && entry.description.present?

    opening, continuation = entry.description.gsub(/\r\n?/, "\n").split(/\n\n+/, 2)
    # Keep a short opening beside the title; longer paragraphs flow below it.
    opening.length <= 500 ? [ opening, continuation ] : [ nil, entry.description ]
  end

  def calendar_entry_path(entry)
    return endeavor_path(entry.endeavor, anchor: "endeavor-next-steps") if entry.is_a?(CalendarDeadline)
    return meeting_path(entry) if entry.is_a?(Meeting)

    calendar_event_path(entry, preview: @month&.public_preview? ? "public" : nil)
  end

  def calendar_entry_time(entry, include_end: true)
    return "Due date · not a scheduled event" if entry.is_a?(CalendarDeadline)
    return nil if entry.is_a?(CalendarEvent) && entry.all_day?

    zone = entry.organization.calendar_time_zone
    starts_at = entry.starts_at.in_time_zone(zone)
    return starts_at.strftime("%H:%M") unless include_end

    ends_at = entry.is_a?(CalendarEvent) ? entry.ends_at&.in_time_zone(zone) : nil
    if ends_at && starts_at.to_date != ends_at.to_date
      return "#{starts_at.strftime('%d %b, %H:%M')} – #{ends_at.strftime('%d %b, %H:%M')}"
    end

    time = starts_at.strftime("%H:%M")
    if entry.is_a?(CalendarEvent) && entry.ends_at
      time += "–#{ends_at.strftime('%H:%M')}"
    end
    time
  end

  def calendar_entry_location(entry)
    return nil if entry.is_a?(CalendarDeadline)

    entry.is_a?(Meeting) ? entry.location_name : entry.location
  end

  def calendar_entry_label(entry)
    return "Due date · Members only" if entry.is_a?(CalendarDeadline)
    return "#{CalendarCategories::LABELS.fetch(CalendarCategories.for(entry))} · Members only" if entry.is_a?(Meeting)

    [ CalendarCategories::LABELS.fetch(CalendarCategories.for(entry)), ("Cancelled" if entry.cancelled?), CalendarEvent::VISIBILITIES.fetch(entry.visibility) ].compact.join(" · ")
  end

  def calendar_schedule_value(event, attribute, part)
    submitted = params[:calendar_event]
    key = "#{attribute}_#{part}"
    return submitted[key] if submitted&.key?(key)

    value = event.public_send(attribute)&.in_time_zone(event.organization.calendar_time_zone)
    part == :date ? legion_date(value) : value&.strftime("%H:%M")
  end
end
