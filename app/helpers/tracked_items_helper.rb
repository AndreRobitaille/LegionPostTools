module TrackedItemsHelper
  # Matches the house status treatment: a coloured word with a dot, never a
  # boxed pill (see .st in application.css).
  def tracked_item_status_tag(tracked_item)
    variant, label =
      if tracked_item.completed?
        [ "st--done", "Completed" ]
      else
        [ "st--tracking", "Still tracking" ]
      end

    tag.span(class: "st #{variant}") do
      tag.span("", class: "st-dot") + label
    end
  end

  # Why this item sits in the bucket it sits in, said in plain English. The
  # officer should never have to reverse-engineer the importance/urgency matrix,
  # and a bare "Important" tag under an "Important" heading says nothing.
  # On a list row the date has its own column, so the reason carries only the
  # judgement. Where it stands alone (the detail rail), pass with_date: true.
  def tracked_item_reason(tracked_item, on: Date.current, with_date: false)
    date = tracked_item.raise_by_on

    if date.blank?
      return tracked_item.important? ? "Important, but no date is forcing it yet." : "No date set — stays on the list until it moves."
    end

    on_date = with_date ? ", on #{legion_date(date)}" : ""

    if date < on
      with_date ? "Overdue since #{legion_date(date)}." : "Overdue — this should already have been raised."
    elsif tracked_item.urgent?(on: on)
      "Due #{tracked_item_days_away(date, on)}#{on_date}."
    elsif tracked_item.important?
      with_date ? "Important, but not due until #{legion_date(date)}." : "Important, but not due for a while yet."
    else
      with_date ? "Not pressing yet — due #{legion_date(date)}." : "Not pressing yet."
    end
  end

  # The one fact worth its own column on a list row.
  def tracked_item_due_label(tracked_item, on: Date.current)
    return nil if tracked_item.raise_by_on.blank?

    tracked_item.raise_by_on < on ? "Overdue since" : "Raise by"
  end

  private

  def tracked_item_days_away(date, on)
    days = (date - on).to_i
    return "today" if days.zero?
    return "tomorrow" if days == 1

    "in #{pluralize(days, 'day')}"
  end
end
