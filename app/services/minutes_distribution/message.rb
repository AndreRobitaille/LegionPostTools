module MinutesDistribution::Message
  module_function

  def variables(issue, delivery)
    payload = issue.minutes_revision.payload
    post_name = issue.document_context.fetch("organization").fetch("name")
    meeting_label = payload.fetch("title")
    meeting_date = Time.zone.parse(payload.fetch("starts_at")).strftime("%B %-d, %Y")
    values = { "post_name" => post_name, "meeting_label" => meeting_label, "meeting_date" => meeting_date,
      "copy_label" => issue.corrected? ? "Corrected minutes" : "Minutes" }
    presentation = issue.document_context.fetch("email_presentation", {})
    values["post_label"] = presentation.fetch("post_label", post_name)
    values["meeting_name"] = presentation.fetch("meeting_name") { MinutesDistribution::Presentation.meeting_name(payload.fetch("meeting_body_name")) }
    approval = if issue.document_context.fetch("status") == "membership_approved"
      "This copy has been attested by the Adjutant and approved by the #{payload.fetch('meeting_body_name')}."
    else
      "They have been attested by the Adjutant but have not yet been approved by the #{payload.fetch('meeting_body_name')}; corrections may be made at its next meeting."
    end
    wording = issue.email_wording.presence || MinutesDistribution::EmailTemplate.legacy_wording(corrected: issue.corrected?)
    note = MinutesDistribution::EmailTemplate.render(wording.fetch("cover_note"), values)
    correction = issue.corrected? && issue.email_wording.present? ? MinutesDistribution::EmailTemplate::CORRECTION_NOTICE : ""
    status = MinutesDistribution::Presentation.status(approved: issue.document_context.fetch("status") == "membership_approved",
      body_name: payload.fetch("meeting_body_name"))
    {
      "subject" => MinutesDistribution::EmailTemplate.render(wording.fetch("subject"), values),
      "recipient_name" => delivery.recipient_snapshot.first.fetch("name"),
      "post_name" => post_name, "meeting_label" => meeting_label, "meeting_date" => meeting_date,
      "document_heading" => "#{values.fetch('meeting_name')} minutes#{' — corrected copy' if issue.corrected?}",
      "message_note" => note, "correction_notice" => correction,
      "status_label" => status.fetch("label"), "status_note" => status.fetch("note"),
      "cover_note" => [ note, correction.presence, approval ].compact.join("\n\n"), "reply_to" => issue.reply_to
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
