module MinutesDistributionsHelper
  def minutes_email_status(minutes)
    settings = minutes.organization.minutes_distribution_setting
    issue = minutes.email_distributions.order(:id).last
    return "Mailing held for officer review" if MinutesDistributionEvent.held?(minutes) || issue&.state == "held"
    if minutes.editable? && issue
      return "The earlier copy was queued or sent; corrected text will be emailed after attestation."
    end
    if issue
      return "No new email needed — the text is unchanged" if issue.deliveries.exists? && issue.deliveries.all? { |delivery| delivery.status == "unchanged" }
      if issue.state == "completed"
        count = issue.deliveries.where(status: "sent").count
        text = "Sent to Loops for #{pluralize(count, 'address')}"
        text += ". No new email needed for unchanged approval." if minutes.membership_approved?
        return text
      end
      return "Needs attention" if issue.state == "needs_attention" || issue.error_message.present?
      return "Preparing PDF and checking recipients" if issue.state == "pending"
      return "Queued for delivery" if issue.state == "ready"
      return "Replaced by a newer attested copy" if issue.state == "superseded"
    end
    return "Automatic minutes email is paused" unless settings&.includes_minutes?(minutes)

    "After attestation: up to #{pluralize(minutes_email_recipient_count(minutes), 'email address')}"
  end

  def minutes_email_recipient_count(minutes)
    recipients = minutes.organization.minutes_recipients.active.where(enrollment_status: "enrolled")
    first = minutes.email_distributions.order(:id).first
    recipients = recipients.where(id: first.deliveries.flat_map { |delivery| delivery.recipient_snapshot.pluck("id") }) if first
    recipients.distinct.count(:email)
  end
end
