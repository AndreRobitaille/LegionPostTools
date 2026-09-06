module CalendarHelper
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

  def calendar_entry_path(entry)
    return endeavor_path(entry.endeavor, anchor: "endeavor-next-steps") if entry.is_a?(CalendarDeadline)
    return meeting_path(entry) if entry.is_a?(Meeting)

    calendar_event_path(entry, preview: @month&.public_preview? ? "public" : nil)
  end

  def calendar_entry_time(entry, block: false)
    return nil if block && entry.is_a?(CalendarEvent) && entry.all_day?
    return "Due date · not a scheduled event" if entry.is_a?(CalendarDeadline)
    return "Date only" if entry.is_a?(CalendarEvent) && entry.all_day?

    zone = entry.organization.calendar_time_zone
    starts_at = entry.starts_at.in_time_zone(zone)
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
