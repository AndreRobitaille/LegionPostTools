module Api
  class MeetingMinutesController < BaseController
    before_action :require_minutes_read_access
    before_action -> { require_capability("manage_minutes") }, only: %i[create update]
    before_action :set_meeting
    before_action :set_minutes, only: %i[show update print]
    before_action :ensure_draft_minutes, only: :update

    def show
      render json: { minutes: minutes_detail_payload(@minutes) }
    end

    def create
      minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
      render json: { minutes: minutes_detail_payload(minutes) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render_validation_error(error.record, fallback: "Minutes could not be started.")
    end

    def update
      @minutes.update!(minutes_params)
      render json: { minutes: minutes_detail_payload(@minutes.reload) }
    rescue ActiveRecord::StaleObjectError
      render_error("These minutes changed while you were editing them. Fetch the current record before saving.", status: :conflict)
    rescue ActiveRecord::RecordInvalid
      render_validation_error(@minutes, fallback: "The minutes heading could not be updated.")
    end

    def print
      pdf = MeetingMinutesPdf.render(minutes: @minutes)
      send_data pdf,
        filename: MeetingMinutesPdf.filename(minutes: @minutes),
        type: "application/pdf",
        disposition: "inline"
      no_store
    rescue MeetingMinutesPdf::GenerationError => error
      Rails.logger.error("API draft minutes PDF generation failed: #{error.message}")
      render_error("The draft PDF could not be created. Try again.", status: :service_unavailable)
    end

    private

    def require_minutes_read_access
      require_authentication
      return if performed?
      return if current_user.can_any?("manage_minutes", "view_internal_records")

      render_error("You do not have permission to open that.", status: :forbidden)
    end

    def set_meeting
      @meeting = organization.meetings.find(params[:meeting_id])
    end

    def set_minutes
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def ensure_draft_minutes
      return if @minutes.draft?

      render_error("Only draft minutes can be changed.", status: :unprocessable_entity)
    end

    def minutes_params
      params.permit(:title, :location_name, :location_address, :lock_version)
    end
  end
end
