module Admin
  class MinutesReopeningsController < ApplicationController
    before_action :set_minutes
    before_action :require_reopening_capability
    before_action :ensure_reopenable

    def new
      @confirmation = confirmation_from_params
      @reason = @confirmation&.action_payload&.fetch("reason", nil)
    end

    def create
      confirmation = confirmation_from_params
      if confirmation&.confirmed_at?
        @minutes.reopen_with_confirmation!(confirmation:)
        clear_pending_confirmation
        redirect_to admin_meeting_minutes_path(@meeting),
          notice: "Minutes reopened. Correct the working record, then repeat Commander approval and Adjutant attestation."
      else
        reason = params.require(:minutes_reopening).fetch(:reason).to_s.strip
        if reason.blank?
          return redirect_to new_admin_meeting_minutes_reopening_path(@meeting),
            alert: "Explain why these minutes need to be reopened."
        end

        confirmation = OfficialActionConfirmation.prepare!(
          minutes: @minutes,
          user: current_user,
          session: Current.session,
          action: "reopen",
          action_payload: { reason: }
        )
        session[OfficialActionReauthenticationsController::PENDING_SESSION_KEY] = confirmation.id
        redirect_to new_official_action_reauthentication_path
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => error
      redirect_to admin_meeting_minutes_path(@meeting),
        alert: error.record&.errors&.full_messages&.to_sentence.presence || "The minutes could not be reopened."
    end

    private

    def set_minutes
      @meeting = Organization.first!.meetings.find(params[:meeting_id])
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def require_reopening_capability
      require_capability(@minutes.attested? ? "attest_minutes" : "approve_minutes")
    end

    def ensure_reopenable
      return if @minutes.approved? || @minutes.attested?

      redirect_to admin_meeting_minutes_path(@meeting),
        alert: "Only Commander-approved or attested minutes can be reopened."
    end

    def confirmation_from_params
      return if params[:confirmation_id].blank?

      current_user.official_action_confirmations.find_by!(
        id: params[:confirmation_id],
        meeting_minutes: @minutes,
        action: "reopen",
        session: Current.session
      )
    end

    def clear_pending_confirmation
      session.delete(OfficialActionReauthenticationsController::PENDING_SESSION_KEY)
    end
  end
end
