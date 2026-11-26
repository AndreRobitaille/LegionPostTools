module Admin
  class MinutesAttestationsController < ApplicationController
    before_action -> { require_capability("attest_minutes") }
    before_action :set_minutes
    before_action :ensure_ready_for_attestation

    include MinutesActionIdentity

    def new
      redirect_to admin_meeting_minutes_path(@meeting)
    end

    def create
      begin_minutes_confirmation("attest")
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
  end
end
