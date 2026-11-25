class MemberCalendarExport
  def initialize(entry, detail_url:)
    @entry = entry
    @detail_url = detail_url
    @zone = entry.organization.calendar_time_zone
    @all_day = entry.is_a?(CalendarEvent) && entry.all_day?
    finish = entry.ends_at if entry.is_a?(CalendarEvent)
    if @all_day
      @start = entry.starts_at.in_time_zone(@zone).to_date
      @finish = (finish || entry.starts_at).in_time_zone(@zone).to_date.next_day
    else
      @start = entry.starts_at.utc
      @finish = finish&.utc
    end
  end

  def available?
    return false if @entry.cancelled?
    return @zone.today < @finish if @all_day

    (@finish || @start) >= Time.current
  end

  def google_url
    params = {
      action: "TEMPLATE", text: @entry.title, details: details, location: location.presence,
      dates: [ @start, @finish || @start ].map { |value| calendar_value(value).value_ical }.join("/"),
      stz: @zone.tzinfo.name, etz: @zone.tzinfo.name
    }
    "https://calendar.google.com/calendar/render?#{params.compact.to_query}"
  end

  def to_ics
    calendar = Icalendar::Calendar.new
    calendar.prodid = "-//LegionPostTools//Member Calendar//EN"
    calendar.event do |event|
      event.uid = "#{@entry.model_name.singular}-#{@entry.id}@#{URI(@detail_url).host}"
      event.dtstamp = Icalendar::Values::DateTime.new(@entry.updated_at.utc, "tzid" => "UTC")
      event.dtstart = calendar_value(@start)
      event.dtend = calendar_value(@finish) if @finish && @finish > @start
      event.summary = ical_text(@entry.title)
      event.location = ical_text(location) if location.present?
      event.url = @detail_url
      event.description = details
    end
    calendar.to_ical
  end

  private

  def location
    return @entry.location if @entry.is_a?(CalendarEvent)

    [ @entry.location_name, @entry.location_address ].compact_blank.join(", ")
  end

  def details
    [ ("End time not specified." unless @finish), @detail_url ].compact.join("\n")
  end

  def calendar_value(value)
    @all_day ? Icalendar::Values::Date.new(value) : Icalendar::Values::DateTime.new(value, "tzid" => "UTC")
  end

  # The gem interprets backslash escapes on input. Preserve literal member-entered text.
  def ical_text(value)
    value.gsub(/\r\n?/, "\n").gsub("\\") { "\\\\" }
  end
end
