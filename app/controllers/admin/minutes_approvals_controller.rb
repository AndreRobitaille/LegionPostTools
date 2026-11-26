module Admin
  class MinutesApprovalsController < ApplicationController
    before_action -> { require_capability("approve_minutes") }
    before_action :set_minutes
    before_action :ensure_draft

    include MinutesActionIdentity

    def new
      redirect_to admin_meeting_minutes_path(@meeting)
    end

    def create
      begin_minutes_confirmation("approve")
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
  end
end
