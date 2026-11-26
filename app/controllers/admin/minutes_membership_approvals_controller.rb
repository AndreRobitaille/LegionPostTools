module Admin
  class MinutesMembershipApprovalsController < ApplicationController
    before_action -> { require_capability("record_minutes_approval") }
    before_action :set_minutes
    before_action :ensure_attested
    before_action :set_eligible_meetings

    include MinutesActionIdentity

    def new; end

    def create
      payload = membership_approval_params.to_h
      validate_action_payload!(payload)
      begin_minutes_confirmation("record_membership_approval", payload)
    rescue ArgumentError => error
      if request.format.json?
        render json: { error: error.message }, status: :unprocessable_entity
      else
        flash.now[:alert] = error.message
        render :new, status: :unprocessable_entity
      end
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
      params.require(:minutes_membership_approval).permit(:approving_meeting_id, :disposition, :factual_note, :corrections_pending)
    end

    def validate_action_payload!(payload)
      @eligible_meetings.find(payload.fetch("approving_meeting_id"))
      unless payload.fetch("disposition", "").in?(MinutesMembershipApproval::DISPOSITIONS)
        raise ArgumentError, "Choose how the membership approved these minutes."
      end
      if payload["disposition"] == "other" && payload["factual_note"].blank?
        raise ArgumentError, "Describe the membership's approval procedure."
      end
      if payload["disposition"] == "approved_as_corrected" && ActiveModel::Type::Boolean.new.cast(payload["corrections_pending"]) && payload["factual_note"].blank?
        raise ArgumentError, "Describe the corrections approved at the meeting."
      end
    rescue ActiveRecord::RecordNotFound, KeyError
      raise ArgumentError, "Choose the later meeting where the membership approved these minutes."
    end
  end
end
