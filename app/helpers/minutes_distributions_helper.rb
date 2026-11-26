module MinutesDistributionsHelper
  def minutes_email_template_markup(text)
    safe_join(text.to_s.split(/(\{\{.*?\}\})/).map do |part|
      part.match?(MinutesDistribution::EmailTemplate::TOKEN) ? tag.code(part, class: "minutes-email-variable") : part
    end)
  end

  def minutes_email_example_values(settings, organization)
    meeting_type = organization.meeting_types.where(id: settings.meeting_type_ids).order(:position).first
    {
      "post_name" => organization.name, "post_label" => MinutesDistribution::Presentation.post_label(organization),
      "meeting_name" => MinutesDistribution::Presentation.meeting_name(meeting_type&.name || "Example meeting"),
      "meeting_label" => meeting_type&.name || "Example meeting",
      "meeting_date" => Time.current.in_time_zone(organization.timezone).strftime("%B %-d, %Y"), "copy_label" => "Minutes"
    }
  end

  def minutes_email_example(text, values)
    return text if MinutesDistribution::EmailTemplate.problems(text).any?

    MinutesDistribution::EmailTemplate.render(text, values)
  end

  def minutes_email_status(minutes, settings:, issue:, meeting_held:)
    return "Mailing paused for this meeting." if meeting_held
    if minutes.editable? && settings&.includes_minutes?(minutes)
      count = minutes_email_recipient_count(minutes)
      return "No office addresses are eligible for this copy." if count.zero?
      addresses = pluralize(count, "eligible address")
      next_mailing = issue ? "Changed copies go to #{addresses} after signing." : "Emailed to #{addresses} after signing."
      return issue&.state == "held" ? "Earlier mailing paused. #{next_mailing}" : next_mailing
    end

    return "This mailing is paused." if issue&.state == "held"
    return "Delivery needs review." if issue&.state == "needs_attention" || issue&.error_message.present?

    case issue&.state
    when "pending" then "Preparing the PDF and checking recipients."
    when "ready" then "PDF queued for delivery."
    when "superseded" then "A newer copy replaced this mailing."
    when "completed"
      results = issue.deliveries.group(:status).count
      return "Text unchanged. No repeat email." if results.keys == [ "unchanged" ]
      return "No email sent." if results.fetch("sent", 0).zero?

      status = "Email service accepted the PDF for #{pluralize(results.fetch('sent'), 'address')}."
      status += " Approval alone sends no new email." if minutes.membership_approved?
      status
    else
      "Automatic email is off for the Post." if minutes.editable? && settings&.meeting_type_ids&.include?(minutes.meeting_type_id)
    end
  end

  def minutes_email_recipient_count(minutes)
    recipients = minutes.organization.minutes_recipients.active.where(enrollment_status: "enrolled")
    first = minutes.email_distributions.order(:id).first
    recipients = recipients.where(id: first.deliveries.flat_map { |delivery| delivery.recipient_snapshot.pluck("id") }) if first
    recipients.distinct.count(:email)
  end
end
