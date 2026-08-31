module Admin
  class MeetingMinutesController < ApplicationController
    before_action :require_minutes_access
    before_action -> { require_capability("manage_minutes") }, only: %i[create edit update]
    before_action :set_meeting
    before_action :set_minutes, only: %i[show edit update print]
    before_action :ensure_draft_minutes, only: %i[edit update]

    def show; end

    def print
      pdf = MeetingMinutesPdf.render(minutes: @minutes)
      send_data pdf,
        filename: MeetingMinutesPdf.filename(minutes: @minutes),
        type: "application/pdf",
        disposition: "inline"
      no_store
    rescue MeetingMinutesPdf::GenerationError => error
      Rails.logger.error("Draft minutes PDF generation failed: #{error.message}")
      redirect_to admin_meeting_minutes_path(@meeting), alert: "The draft PDF could not be created. Try again."
    end

    def create
      minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
      redirect_to admin_meeting_minutes_path(@meeting), notice: "Minutes workspace created from the meeting record."
    rescue ActiveRecord::RecordInvalid => error
      message = error.record.errors.full_messages.to_sentence.presence || "Minutes could not be started."
      redirect_to admin_meeting_path(@meeting), alert: message
    end

    def edit; end

    def update
      @minutes.update!(minutes_params)
      redirect_to admin_meeting_minutes_path(@meeting), notice: "Minutes heading updated."
    rescue ActiveRecord::StaleObjectError
      redirect_to admin_meeting_minutes_path(@meeting), alert: "The minutes heading changed while you were editing it. Review the latest version."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    private

    def require_minutes_access
      require_any_capability("manage_minutes", "view_internal_records")
    end

    def set_meeting
      organization = Organization.first!
      @meeting = organization.meetings.includes(
        :dated_agenda,
        :transcript,
        minutes: [
          :attendance_entries,
          { sections: { items: %i[rich_text_agenda_body rich_text_body endeavor outcomes source_dated_agenda_item] } }
        ]
      ).find(params[:meeting_id])
    end

    def set_minutes
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def ensure_draft_minutes
      return if @minutes.draft?

      redirect_to admin_meeting_minutes_path(@meeting), alert: "Reopen these minutes before changing the working record."
    end

    def minutes_params
      params.require(:meeting_minutes).permit(
        :title,
        :location_name,
        :location_address,
        :lock_version
      )
    end
  end
end
