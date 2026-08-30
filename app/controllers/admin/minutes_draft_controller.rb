module Admin
  class MinutesDraftController < ApplicationController
    before_action -> { require_capability("manage_minutes") }
    before_action :set_meeting_and_minutes
    before_action :ensure_draft_minutes

    private

    def set_meeting_and_minutes
      @organization = Organization.first!
      @meeting = @organization.meetings.find(params[:meeting_id])
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def ensure_draft_minutes
      return if @minutes.draft?

      redirect_to admin_meeting_minutes_path(@meeting), alert: "Reopen these minutes before changing the working record."
    end

    def workspace_path
      admin_meeting_minutes_path(@meeting)
    end

    def moved_record_ids(records, record)
      current = records.index(record)
      target = params[:direction] == "up" ? current - 1 : current + 1
      valid_move = params[:direction].in?(%w[up down]) && target.between?(0, records.length - 1)
      raise ActiveRecord::RecordNotFound unless valid_move

      records[current], records[target] = records[target], records[current]
      records.map(&:id)
    end
  end
end
