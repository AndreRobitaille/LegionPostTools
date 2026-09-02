module Admin
  class MinutesMembershipApprovalsController < ApplicationController
    before_action -> { require_capability("record_minutes_approval") }
    before_action :set_minutes
    before_action :ensure_attested
    before_action :set_eligible_meetings

    def new
      @confirmation = confirmation_from_params
      @approval_attributes = @confirmation&.action_payload || {}
    end

    def create
      confirmation = confirmation_from_params
      if confirmation&.confirmed_at?
        approval = @minutes.record_membership_approval_with_confirmation!(confirmation:)
        clear_pending_confirmation
        redirect_to admin_meeting_minutes_path(@meeting),
          notice: "Membership approval recorded: #{approval.disposition_label}."
      else
        action_payload = membership_approval_params.to_h
        validate_action_payload!(action_payload)
        confirmation = OfficialActionConfirmation.prepare!(
          minutes: @minutes,
          user: current_user,
          session: Current.session,
          action: "record_membership_approval",
          action_payload:
        )
        session[OfficialActionReauthenticationsController::PENDING_SESSION_KEY] = confirmation.id
        redirect_to new_official_action_reauthentication_path
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => error
      redirect_to admin_meeting_minutes_path(@meeting),
        alert: error.record&.errors&.full_messages&.to_sentence.presence || "Membership approval could not be recorded."
    rescue ArgumentError => error
      redirect_to new_admin_meeting_minutes_membership_approval_path(@meeting), alert: error.message
    end

    private

    def set_minutes
      @meeting = Organization.first!.meetings.find(params[:meeting_id])
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def ensure_attested
      return if @minutes.attested?

      redirect_to admin_meeting_minutes_path(@meeting),
        alert: "Only an exact attested revision can be recorded as approved by the membership."
    end

    def set_eligible_meetings
      @eligible_meetings = @minutes.eligible_membership_approval_meetings
    end

    def membership_approval_params
      params.require(:minutes_membership_approval).permit(:approving_meeting_id, :disposition, :factual_note)
    end

    def validate_action_payload!(payload)
      @eligible_meetings.find(payload.fetch("approving_meeting_id"))
      unless payload.fetch("disposition", "").in?(MinutesMembershipApproval::DISPOSITIONS)
        raise ArgumentError, "Choose how the membership approved these minutes."
      end
      if payload["disposition"] == "other" && payload["factual_note"].blank?
        raise ArgumentError, "Describe the membership's approval procedure."
      end
    rescue ActiveRecord::RecordNotFound, KeyError
      raise ArgumentError, "Choose the later meeting where the membership approved these minutes."
    end

    def confirmation_from_params
      return if params[:confirmation_id].blank?

      current_user.official_action_confirmations.find_by!(
        id: params[:confirmation_id],
        meeting_minutes: @minutes,
        action: "record_membership_approval",
        session: Current.session
      )
    end

    def clear_pending_confirmation
      session.delete(OfficialActionReauthenticationsController::PENDING_SESSION_KEY)
    end
  end
end
