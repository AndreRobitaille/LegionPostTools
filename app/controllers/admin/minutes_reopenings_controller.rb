module Admin
  class MinutesReopeningsController < ApplicationController
    before_action :set_minutes
    before_action :require_reopening_capability
    before_action :ensure_reopenable

    include MinutesActionIdentity

    def new; end

    def create
      reason = params.require(:minutes_reopening).fetch(:reason, "").to_s.strip
      if reason.blank?
        return redirect_to new_admin_meeting_minutes_reopening_path(@meeting), alert: "Enter a reason for reopening these minutes."
      end

      begin_minutes_confirmation("reopen", { reason: })
    end

    private

    def set_minutes
      @meeting = Organization.first!.meetings.find(params[:meeting_id])
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def require_reopening_capability
      require_capability("manage_minutes")
    end

    def ensure_reopenable
      return if @minutes.approved? || @minutes.attested?

      redirect_to admin_meeting_minutes_path(@meeting),
        alert: "Only a draft handed to the Adjutant or an attested copy can be reopened."
    end
  end
end
