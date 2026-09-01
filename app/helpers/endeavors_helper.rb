module EndeavorsHelper
  # Matches the house status treatment: a coloured word with a dot, never a
  # boxed pill (see .st in application.css).
  def endeavor_status_tag(endeavor)
    variant, label =
      if endeavor.completed?
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
  def endeavor_reason(endeavor, on: Date.current, with_date: false)
    return "Completed on #{legion_date(endeavor.completed_at)}." if endeavor.completed?

    date = endeavor.raise_by_on

    if date.blank?
      return endeavor.important? ? "Important, but no date is forcing it yet." : "No date set — stays on the list until it moves."
    end

    on_date = with_date ? ", on #{legion_date(date)}" : ""

    if date < on
      with_date ? "Overdue since #{legion_date(date)}." : "Overdue — this should already have been raised."
    elsif endeavor.urgent?(on: on)
      "Due #{endeavor_days_away(date, on)}#{on_date}."
    elsif endeavor.important?
      with_date ? "Important, but not due until #{legion_date(date)}." : "Important, but not due for a while yet."
    else
      with_date ? "Not pressing yet — due #{legion_date(date)}." : "Not pressing yet."
    end
  end

  # The one fact worth its own column on a list row.
  def endeavor_due_label(endeavor, on: Date.current)
    return nil if endeavor.completed? || endeavor.raise_by_on.blank?

    endeavor.raise_by_on < on ? "Overdue since" : "Raise by"
  end

  def endeavor_timeline_document(agenda)
    if agenda.meeting.minutes&.attested?
      [ "Read the attested minutes", meeting_minutes_path(agenda.meeting) ]
    elsif agenda.published?
      [ "Read the published agenda", dated_agenda_path(agenda) ]
    end
  end

  private

  def endeavor_days_away(date, on)
    days = (date - on).to_i
    return "today" if days.zero?
    return "tomorrow" if days == 1

    "in #{pluralize(days, 'day')}"
  end
end
