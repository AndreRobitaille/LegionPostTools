module Api
  class MeetingsController < BaseController
    before_action :require_meeting_read_access, only: %i[index show]
    before_action -> { require_capability("manage_agendas") }, only: %i[create update destroy]
    before_action :set_meeting, only: %i[show update destroy]

    def index
      render json: { meetings: ordered_meetings.map { |meeting| meeting_payload(meeting) } }
    end

    def show
      render json: { meeting: meeting_payload(@meeting) }
    end

    def create
      meeting = organization.meetings.new(meeting_attributes)
      meeting.save!
      render json: { meeting: meeting_payload(meeting) }, status: :created
    rescue ArgumentError, ActiveRecord::RecordInvalid => error
      record = error.record if error.respond_to?(:record)
      render_error(
        record&.errors&.full_messages&.to_sentence.presence || error.message,
        status: :unprocessable_entity,
        details: Array(record&.errors&.full_messages)
      )
    end

    def update
      if @meeting.update_with_agenda_sync(meeting_attributes)
        render json: { meeting: meeting_payload(@meeting.reload) }
      else
        render_validation_error(@meeting, fallback: "Could not update this meeting.")
      end
    rescue ArgumentError => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    rescue ActiveRecord::StaleObjectError
      render_error("This meeting was changed by someone else. Fetch it again before saving.", status: :conflict)
    end

    def destroy
      unless @meeting.empty_record?
        return render_error("Remove the meeting's agenda and other draft documents before deleting the meeting. Historical records cannot be deleted.", status: :unprocessable_entity)
      end

      deleted = meeting_payload(@meeting)
      @meeting.destroy!
      render json: { deleted_meeting: deleted }
    rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError
      render_validation_error(@meeting, fallback: "This meeting has historical records and cannot be deleted.")
    end

    private

    def require_meeting_read_access
      require_authentication
      return if performed?
      return if current_user.can_any?("manage_agendas", "manage_minutes", "view_internal_records")

      render_error("You do not have permission to open that.", status: :forbidden)
    end

    def set_meeting
      @meeting = organization.meetings.includes(meeting_includes).find(params[:id])
    end

    def ordered_meetings
      meetings = organization.meetings.includes(meeting_includes)
      meetings.upcoming.to_a + meetings.past.to_a
    end

    def meeting_includes
      [ :meeting_body, :meeting_type, :dated_agenda, { transcript: { created_by: :person } }, :minutes ]
    end

    def meeting_attributes
      permitted = params.permit(
        :meeting_body_id,
        :meeting_type_id,
        :starts_at,
        :title,
        :location_name,
        :location_address,
        :lock_version
      ).to_h.symbolize_keys

      if permitted.key?(:starts_at)
        permitted[:starts_at] = Time.zone.parse(permitted[:starts_at].to_s)
        raise ArgumentError, "starts_at can't be blank" if permitted[:starts_at].blank?
      end

      permitted
    end
  end
end
