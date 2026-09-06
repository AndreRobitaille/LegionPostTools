module CalendarHelper
  def calendar_entry_path(entry)
    return endeavor_path(entry.endeavor, anchor: "endeavor-next-steps") if entry.is_a?(CalendarDeadline)
    return meeting_path(entry) if entry.is_a?(Meeting)

    calendar_event_path(entry, preview: @month&.public_preview? ? "public" : nil)
  end

  def calendar_entry_time(entry)
    return "Due date · not a scheduled event" if entry.is_a?(CalendarDeadline)
    return "Date only" if entry.is_a?(CalendarEvent) && entry.all_day?

    if entry.is_a?(CalendarEvent) && entry.ends_at && entry.starts_at.to_date != entry.ends_at.to_date
      return "#{entry.starts_at.strftime('%d %b, %H:%M')} – #{entry.ends_at.strftime('%d %b, %H:%M')}"
    end

    time = entry.starts_at.strftime("%H:%M")
    if entry.is_a?(CalendarEvent) && entry.ends_at
      time += "–#{entry.ends_at.strftime('%H:%M')}"
    end
    time
  end

  def calendar_entry_location(entry)
    return nil if entry.is_a?(CalendarDeadline)

    entry.is_a?(Meeting) ? entry.location_name : entry.location
  end

  def calendar_entry_label(entry)
    return "Due date · Members only" if entry.is_a?(CalendarDeadline)
    return "Meeting · Members only" if entry.is_a?(Meeting)

    [ ("Cancelled" if entry.cancelled?), CalendarEvent::VISIBILITIES.fetch(entry.visibility) ].compact.join(" · ")
  end

  def calendar_schedule_value(event, attribute, part)
    submitted = params[:calendar_event]
    key = "#{attribute}_#{part}"
    return submitted[key] if submitted&.key?(key)

    value = event.public_send(attribute)
    part == :date ? legion_date(value) : value&.strftime("%H:%M")
  end
end
