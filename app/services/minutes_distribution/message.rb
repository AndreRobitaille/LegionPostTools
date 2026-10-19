module MinutesDistribution::Message
  module_function

  def variables(issue, delivery)
    payload = issue.minutes_revision.payload
    post_name = issue.document_context.fetch("organization").fetch("name")
    meeting_label = payload.fetch("title")
    meeting_date = Time.zone.parse(payload.fetch("starts_at")).strftime("%B %-d, %Y")
    values = { "post_name" => post_name, "meeting_label" => meeting_label, "meeting_date" => meeting_date,
      "copy_label" => issue.corrected? ? "Corrected minutes" : "Minutes" }
    approval = if issue.document_context.fetch("status") == "membership_approved"
      "This copy has been attested by the Adjutant and approved by the #{payload.fetch('meeting_body_name')}."
    else
      "They have been attested by the Adjutant but have not yet been approved by the #{payload.fetch('meeting_body_name')}; corrections may be made at its next meeting."
    end
    wording = issue.email_wording.presence || MinutesDistribution::EmailTemplate.legacy_wording(corrected: issue.corrected?)
    note = MinutesDistribution::EmailTemplate.render(wording.fetch("cover_note"), values)
    if issue.corrected? && issue.email_wording.present?
      note += "\n\n#{MinutesDistribution::EmailTemplate::CORRECTION_NOTICE}"
    end
    {
      "subject" => MinutesDistribution::EmailTemplate.render(wording.fetch("subject"), values),
      "recipient_name" => delivery.recipient_snapshot.first.fetch("name"),
      "post_name" => post_name, "meeting_label" => meeting_label, "meeting_date" => meeting_date,
      "cover_note" => "#{note}\n\n#{approval}", "reply_to" => issue.reply_to
    }
  end

  def payload(issue, delivery)
    {
      transactionalId: issue.template_id, email: delivery.email, addToAudience: false,
      dataVariables: delivery.variables,
      attachments: [ { filename: issue.filename, contentType: "application/pdf", data: Base64.strict_encode64(issue.pdf.download) } ]
    }
  end
end
