module MeetingMinutesHelper
  MINUTES_DOCUMENT_PRESENTATIONS = {
    "draft" => {
      kind: "Draft minutes",
      status: "Draft - not approved",
      authority: "Working draft - not approved, attested, or accepted"
    },
    "approved" => {
      kind: "Approved minutes",
      status: "Approved - awaiting attestation",
      authority: "Approved for attestation - officer-only"
    },
    "attested" => {
      kind: "Attested minutes",
      status: "Attested - awaiting acceptance",
      authority: "Attested minutes - awaiting acceptance"
    },
    "accepted" => {
      kind: "Official minutes",
      status: "Official minutes",
      authority: "Accepted official minutes"
    }
  }.freeze

  def minutes_document_presentation(minutes)
    MINUTES_DOCUMENT_PRESENTATIONS.fetch(minutes.status)
  end

  def minutes_document_payload(minutes)
    minutes.draft? ? minutes.revision_payload : minutes.current_revision.payload
  end

  def minutes_pdf_action_label(minutes)
    {
      "draft" => "Open draft PDF",
      "approved" => "Open approved PDF",
      "attested" => "Open attested PDF",
      "accepted" => "Open official PDF"
    }.fetch(minutes.status)
  end
end
