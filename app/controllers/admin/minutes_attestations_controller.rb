module Admin
  class MinutesAttestationsController < ApplicationController
    before_action -> { require_capability("attest_minutes") }
    before_action :set_minutes
    before_action :ensure_ready_for_attestation

    def new
      @confirmation = confirmation_from_params
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_meeting_minutes_path(@meeting), alert: "That attestation request is invalid or expired."
    end

    def create
      confirmation = confirmation_from_params
      if confirmation&.confirmed_at?
        notice = confirmation.complete_minutes_action!
        clear_pending_confirmation
        redirect_to admin_meeting_minutes_path(@meeting), notice:
      else
        confirmation ||= OfficialActionConfirmation.prepare!(
          minutes: @minutes,
          user: current_user,
          session: Current.session,
          action: "attest"
        )
        session[OfficialActionReauthenticationsController::PENDING_SESSION_KEY] = confirmation.id
        redirect_to new_official_action_reauthentication_path
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => error
      redirect_to admin_meeting_minutes_path(@meeting),
        alert: error.record&.errors&.full_messages&.to_sentence.presence || "The minutes could not be attested."
    end

    private

    def set_minutes
      @meeting = Organization.first!.meetings.find(params[:meeting_id])
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def ensure_ready_for_attestation
      unless @minutes.editable?
        return redirect_to admin_meeting_minutes_path(@meeting), alert: "These minutes are already attested or approved and locked."
      end
      return if @minutes.approval_ready?

      redirect_to admin_meeting_minutes_path(@meeting), alert: "Finish attendance and AI review before attesting these minutes."
    end

    def confirmation_from_params
      return if params[:confirmation_id].blank?

      current_user.official_action_confirmations.find_by!(
        id: params[:confirmation_id],
        meeting_minutes: @minutes,
        action: "attest",
        session: Current.session
      )
    end

    def clear_pending_confirmation
      session.delete(OfficialActionReauthenticationsController::PENDING_SESSION_KEY)
    end
  end
end
