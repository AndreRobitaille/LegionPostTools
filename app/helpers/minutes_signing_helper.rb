module MinutesSigningHelper
  def minutes_signing_labels(action, minutes)
    case action
    when "approve" then { heading: "Send to Adjutant", passkey: "Send with my passkey", email: "Send to Adjutant" }
    when "attest"
      if minutes.pending_correction_approval
        { heading: "Confirm corrections and lock minutes", passkey: "Lock with my passkey", email: "Attest and lock" }
      else
        { heading: "Attest and share with members", passkey: "Attest with my passkey", email: "Attest and share" }
      end
    when "reopen" then { heading: "Reopen for correction", passkey: "Reopen with my passkey", email: "Reopen minutes" }
    when "record_membership_approval" then { heading: "Record meeting approval", passkey: "Record with my passkey", email: "Record approval" }
    end
  end

  def minutes_signing_consequence(action, minutes, payload = {})
    case action
    when "approve"
      minutes.member_visible? ? "The Adjutant can edit this draft. Members still see the last attested copy." : "The Adjutant can edit this draft. Only officers can see it."
    when "attest"
      minutes.pending_correction_approval ? "This corrected copy becomes the locked, official record." : "Members can read this copy while it awaits meeting approval."
    when "reopen"
      minutes.member_visible? ? "Members can still read the last attested copy while you enter corrections." : "The draft becomes editable. Only officers can see it."
    when "record_membership_approval"
      if payload.empty?
        "Recording approval locks this copy unless there are corrections still to enter."
      elsif payload["disposition"] == "approved_as_corrected" && ActiveModel::Type::Boolean.new.cast(payload["corrections_pending"])
        "The decision is recorded. The Adjutant locks the corrected copy after the corrections are entered."
      else
        "Recording approval locks this exact copy."
      end
    end
  end

  def pending_minutes_signature(minutes, action)
    id = session[MinutesActionIdentity::SESSION_KEY]&.fetch("id")
    return unless id && params[:confirmation_id].to_s == id.to_s

    current_user.official_action_confirmations.find_by(id:, meeting_minutes: minutes, action:, session: Current.session,
      consumed_at: nil)
  end
end
