module EndeavorsHelper
  def endeavor_history_status_description(status)
    {
      "withdrawn" => "Generated history is hidden and processing is paused.",
      "processing" => "An update is queued or running.",
      "failed" => "The latest attempt failed. Open history to inspect it.",
      "no_minutes" => "History can begin when attested minutes are available.",
      "not_generated" => "Minutes are available to build a first update.",
      "outdated" => "Minutes or generation inputs have changed since publication.",
      "current" => "Published history matches the current minutes and settings."
    }.fetch(status)
  end

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

    date = endeavor.due_on

    if date.blank?
      return endeavor.important? ? "Important, but no date is forcing it yet." : "No date set — stays on the list until it moves."
    end

    on_date = with_date ? ", on #{legion_date(date)}" : ""

    if date < on
      with_date ? "Overdue since #{legion_date(date)}." : "Overdue — the due date has passed."
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
    return nil if endeavor.completed? || endeavor.due_on.blank?

    endeavor.due_on < on ? "Overdue since" : "Due"
  end

  def endeavor_timeline_document(agenda)
    if agenda.meeting.minutes&.member_visible?
      label = agenda.meeting.minutes.membership_approved? ? "Read the official minutes" : "Read the attested minutes"
      [ label, meeting_minutes_path(agenda.meeting) ]
    elsif agenda.published?
      [ "Read the published agenda", dated_agenda_path(agenda) ]
    end
  end

  def endeavor_outcome_symbol(disposition)
    { "adopted" => "✓", "lost" => "×", "withdrawn" => "−", "postponed" => "↷", "referred" => "→" }.fetch(disposition, "·")
  end

  def endeavor_history_claim_groups(history, entry)
    outcome_ids = entry[:items].flat_map { |item| item["units"].select { |unit| unit["kind"] == "outcome" }.pluck("id") }
    evidence = history.edition.payload.fetch("evidence").find { |meeting| meeting["revision_id"] == entry[:revision].id }
    decision_fact_ids = evidence.fetch("facts").select { |fact| (fact["source_ids"] & outcome_ids).any? }.pluck("id")
    decisions, discussion = entry[:claims].partition { |claim| (claim["fact_ids"] & decision_fact_ids).any? }
    [ [ "Decisions", decisions ], [ decisions.any? ? "Discussion and updates" : "Meeting updates", discussion ] ].reject { |_title, claims| claims.empty? }
  end

  def endeavor_history_error(category)
    {
      "disabled" => "Automatic history is not enabled for this installation yet.",
      "no_sources" => "No member-visible minutes are available yet.",
      "withdrawn" => "Automatic history is paused. Resume it before refreshing.",
      "forbidden" => "The requester no longer has permission to manage this history.",
      "source_changed" => "The sources or guidance changed. A fresh run will use the current record.",
      "daily_budget" => "The daily AI token budget has been reached. Retry after the budget resets.",
      "call_budget" => "This run reached its call limit. An administrator can adjust the processing budget.",
      "input_limit" => "The complete source exceeds the configured input limit; no text was discarded.",
      "verification_failed" => "The generated update did not pass its source check. Review the findings or rerun with guidance.",
      "coverage" => "The generated update did not preserve all required source items or facts.",
      "ambiguous" => "The Endeavor match was ambiguous. Clarifying guidance may help.",
      "configuration" => "The AI provider configuration needs attention."
    }.fetch(category.to_s, "The history run could not finish (#{category.to_s.humanize.downcase}). Its sources and prior record are preserved.")
  end

  private

  def endeavor_days_away(date, on)
    days = (date - on).to_i
    return "today" if days.zero?
    return "tomorrow" if days == 1

    "in #{pluralize(days, 'day')}"
  end
end
