module MinutesDraftSuggestionsHelper
  def minutes_suggestion_kind_label(suggestion)
    {
      "item_summary" => "Draft paragraph",
      "outcome" => "Motion or decision",
      "attendance" => "Attendance",
      "additional_item" => "Unplanned business"
    }.fetch(suggestion.kind)
  end

  def minutes_suggestion_target_label(suggestion)
    suggestion.minutes_item&.title ||
      suggestion.minutes_attendance_entry&.then { |entry| [ entry.office_name, entry.person_name ].compact.join(" — ") } ||
      suggestion.minutes_section&.title
  end

  def minutes_suggestion_proposal(suggestion)
    case suggestion.kind
    when "item_summary"
      suggestion.payload.fetch("body")
    when "outcome"
      [
        suggestion.payload.fetch("text"),
        "Disposition: #{suggestion.payload.fetch('disposition').humanize}",
        ("Moved by: #{suggestion.payload['mover_name']}" if suggestion.payload["mover_name"]),
        ("Seconded by: #{suggestion.payload['seconder_name']}" if suggestion.payload["seconder_name"]),
        suggestion.payload["vote_summary"]
      ].compact.join("\n")
    when "attendance"
      "Mark #{suggestion.payload.fetch('status').humanize.downcase}."
    when "additional_item"
      [
        suggestion.payload.fetch("title"),
        suggestion.payload.fetch("body")
      ].join("\n")
    end
  end

  def minutes_suggestion_endeavor_label(suggestion)
    suggestion.payload["endeavor_title"] if suggestion.kind == "additional_item"
  end

  def minutes_draft_error_message(run)
    {
      "configuration" => "OpenAI is not configured for this installation. Continue manually or ask an administrator to check the encrypted credential.",
      "timeout" => "OpenAI did not finish in time. Retry the draft or continue manually.",
      "rate_limit" => "OpenAI is temporarily busy for this API project. Retry later or continue manually.",
      "invalid_output" => "The response could not be safely matched to this agenda and transcript. Nothing was applied.",
      "incomplete" => "OpenAI returned an incomplete draft. Nothing was applied.",
      "refusal" => "OpenAI did not return draft suggestions. Nothing was applied.",
      "source_unavailable" => "The transcript source is no longer available for drafting.",
      "provider_error" => "OpenAI could not create the draft. Retry later or continue manually."
    }.fetch(run.error_category, "The draft could not be created. Nothing was applied to the minutes.")
  end
end
