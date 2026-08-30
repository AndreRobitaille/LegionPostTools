module Admin
  class MeetingTranscriptsController < ApplicationController
    before_action :require_transcript_access
    before_action -> { require_capability("manage_minutes") }, only: %i[new create]
    before_action :set_meeting

    def show
      @transcript = @meeting.transcript || raise(ActiveRecord::RecordNotFound)
    end

    def new
      return redirect_to admin_meeting_transcript_path(@meeting) if @meeting.transcript.present?

      @transcript = @meeting.build_transcript(retention_policy: "delete_after_acceptance")
    end

    def create
      @transcript = MeetingTranscripts::Create.new(
        meeting: @meeting,
        created_by: current_user,
        retention_policy: transcript_params[:retention_policy],
        pasted_text: transcript_params[:pasted_text].presence,
        text_upload: transcript_params[:text_upload]
      ).call
      destination = @meeting.minutes ? admin_meeting_minutes_path(@meeting) : admin_meeting_path(@meeting)
      redirect_to destination, notice: "Restricted transcript source added."
    rescue ActiveRecord::RecordInvalid => error
      @transcript = error.record
      render :new, status: :unprocessable_entity
    end

    private

    def require_transcript_access
      require_any_capability("manage_minutes", "view_internal_records")
    end

    def set_meeting
      @meeting = Organization.first!.meetings.includes(:minutes, :transcript).find(params[:meeting_id])
    end

    def transcript_params
      params.require(:meeting_transcript).permit(:pasted_text, :text_upload, :retention_policy)
    end
  end
end
