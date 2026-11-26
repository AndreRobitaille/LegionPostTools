module MeetingMinutesHelper
  MINUTES_DOCUMENT_PRESENTATIONS = {
    "draft" => {
      kind: "Draft minutes",
      status: "Draft - not approved",
      authority: "Working draft - not attested or approved by the meeting"
    },
    "approved" => {
      kind: "Draft minutes",
      status: "Draft - ready for Adjutant review",
      authority: "Editable draft awaiting Adjutant attestation"
    },
    "attested" => {
      kind: "Attested minutes",
      status: "Attested - awaiting meeting approval",
      authority: "Attested minutes - awaiting meeting approval"
    },
    "membership_approved" => {
      kind: "Official minutes",
      status: "Official - approved and locked",
      authority: "Official minutes approved by the meeting body"
    }
  }.freeze

  def minutes_document_presentation(minutes)
    if minutes.pending_correction_approval
      return {
        kind: "Corrected draft minutes",
        status: "Corrections pending - meeting approval recorded",
        authority: "Working copy awaiting Adjutant confirmation of the adopted corrections"
      }
    end

    MINUTES_DOCUMENT_PRESENTATIONS.fetch(minutes.status)
  end

  def minutes_document_payload(minutes)
    minutes.editable? ? minutes.revision_payload : minutes.current_revision.payload
  end

  def minutes_pdf_action_label(minutes)
    {
      "draft" => "Open draft PDF",
      "approved" => "Open draft PDF",
      "attested" => "Open attested PDF",
      "membership_approved" => "Open official PDF"
    }.fetch(minutes.status)
  end

  def minutes_workflow_status(minutes)
    if minutes.membership_approved?
      "Approved and locked"
    elsif minutes.pending_correction_approval
      "Corrections to finish"
    elsif minutes.attested?
      "Attested — awaiting meeting approval"
    elsif minutes.approved?
      "Ready for Adjutant review"
    elsif minutes.reopened?
      "Draft corrections"
    else
      "Draft"
    end
  end

  def minutes_workflow_explanation(minutes)
    if minutes.membership_approved?
      "Members can read the final record."
    elsif minutes.pending_correction_approval
      "The meeting approved these minutes with corrections. Members can still read the last attested copy while the final copy is prepared."
    elsif minutes.attested?
      "Members can read the attested copy."
    elsif minutes.approved?
      "The Commander sent this draft to the Adjutant for review."
    elsif minutes.reopened?
      if minutes.member_visible?
        "Either officer can correct the draft. The last attested copy remains available to members."
      else
        "Either officer can correct the draft. It remains officer-only until the Adjutant attests it."
      end
    else
      "Visible only to officers."
    end
  end

  def minutes_next_action(minutes)
    meeting = minutes.meeting
    if minutes.editable? && minutes.approval_ready?
      if current_user.can?("attest_minutes")
        { signing: "attest", path: admin_meeting_minutes_attestation_path(meeting) }
      elsif minutes.draft? && current_user.can?("approve_minutes")
        { signing: "approve", path: admin_meeting_minutes_approval_path(meeting) }
      end
    elsif minutes.attested? && current_user.can?("record_minutes_approval")
      { label: "Record meeting approval", path: new_admin_meeting_minutes_membership_approval_path(meeting) }
    end
  end

  def minutes_next_officer(minutes)
    return if minutes.membership_approved?
    return "Next: enter the corrections, then the Adjutant confirms the final copy." if minutes.pending_correction_approval
    return "Next: Commander or Adjutant records the decision made at the later meeting." if minutes.attested?

    "Next: the Adjutant reviews and attests the finished draft."
  end

  def minutes_progress_step(minutes)
    return 3 if minutes.membership_approved?
    return 2 if minutes.attested?

    1
  end
end
