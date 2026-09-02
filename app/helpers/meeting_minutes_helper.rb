module MeetingMinutesHelper
  MINUTES_DOCUMENT_PRESENTATIONS = {
    "draft" => {
      kind: "Draft minutes",
      status: "Draft - not approved",
      authority: "Working draft - not Commander-approved, attested, or membership-approved"
    },
    "approved" => {
      kind: "Commander-approved minutes",
      status: "Commander-approved - awaiting attestation",
      authority: "Commander-approved for attestation - officer-only"
    },
    "attested" => {
      kind: "Attested minutes",
      status: "Attested - awaiting membership approval",
      authority: "Attested minutes - awaiting membership approval"
    },
    "membership_approved" => {
      kind: "Official minutes",
      status: "Official - membership approved",
      authority: "Official minutes approved by the membership"
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
      "membership_approved" => "Open official PDF"
    }.fetch(minutes.status)
  end
end
