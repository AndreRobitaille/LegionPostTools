module Admin
  class MinutesApprovalsController < ApplicationController
    before_action -> { require_capability("approve_minutes") }
    before_action :set_minutes
    before_action :ensure_draft

    def new
      @confirmation = confirmation_from_params
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_meeting_minutes_path(@meeting), alert: "That approval request is invalid or expired."
    end

    def create
      confirmation = confirmation_from_params
      if confirmation&.confirmed_at?
        @minutes.approve_with_confirmation!(confirmation:)
        clear_pending_confirmation
        redirect_to admin_meeting_minutes_path(@meeting), notice: "Exact minutes revision Commander-approved for Adjutant attestation."
      else
        confirmation ||= OfficialActionConfirmation.prepare!(
          minutes: @minutes,
          user: current_user,
          session: Current.session,
          action: "approve"
        )
        session[OfficialActionReauthenticationsController::PENDING_SESSION_KEY] = confirmation.id
        redirect_to new_official_action_reauthentication_path
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => error
      redirect_to admin_meeting_minutes_path(@meeting),
        alert: error.record&.errors&.full_messages&.to_sentence.presence || "The minutes could not be approved."
    end

    private

    def set_minutes
      @meeting = Organization.first!.meetings.find(params[:meeting_id])
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def ensure_draft
      return if @minutes.draft?
      redirect_to admin_meeting_minutes_path(@meeting), alert: "Only draft minutes can be approved."
    end

    def confirmation_from_params
      return if params[:confirmation_id].blank?

      current_user.official_action_confirmations.find_by!(
        id: params[:confirmation_id],
        meeting_minutes: @minutes,
        action: "approve",
        session: Current.session
      )
    end

    def clear_pending_confirmation
      session.delete(OfficialActionReauthenticationsController::PENDING_SESSION_KEY)
    end
  end
end
