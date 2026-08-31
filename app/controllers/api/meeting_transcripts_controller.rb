module Api
  class MeetingTranscriptsController < BaseController
    before_action :require_transcript_access
    before_action -> { require_capability("manage_minutes") }, only: :create
    before_action :set_meeting

    def show
      transcript = @meeting.transcript || raise(ActiveRecord::RecordNotFound)
      payload = transcript_summary_payload(transcript)
      if ActiveModel::Type::Boolean.new.cast(params[:include_content])
        payload[:content] = transcript.source_available? ? transcript.source_text : nil
      end
      render json: { transcript: payload }
    rescue MeetingTranscript::SourcePurgedError
      render_error("The transcript source has been purged.", status: :gone)
    end

    def create
      transcript = MeetingTranscripts::Create.new(
        meeting: @meeting,
        created_by: current_user,
        retention_policy: params.require(:retention_policy),
        pasted_text: params.require(:transcript_content)
      ).call
      render json: { transcript: transcript_summary_payload(transcript) }, status: :created
    rescue ActionController::ParameterMissing => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    rescue ActiveRecord::RecordInvalid => error
      render_validation_error(error.record, fallback: "The transcript source could not be added.")
    end

    private

    def require_transcript_access
      require_authentication
      return if performed?
      return if current_user.can_any?("manage_minutes", "view_internal_records")

      render_error("You do not have permission to open that.", status: :forbidden)
    end

    def set_meeting
      @meeting = organization.meetings.includes(transcript: { created_by: :person }).find(params[:meeting_id])
    end
  end
end
