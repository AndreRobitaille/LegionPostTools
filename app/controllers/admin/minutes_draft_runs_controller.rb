module Admin
  class MinutesDraftRunsController < MinutesDraftController
    before_action :set_run, only: :show
    before_action :ensure_transcript_source, only: %i[new create]

    def new
      @transcript = @meeting.transcript
    end

    def create
      run = MinutesDrafting::Generate.call(minutes: @minutes, requester: current_user)
      redirect_to admin_meeting_minutes_draft_run_path(@meeting, run), notice: "AI suggestions are ready for review. Nothing was added to the minutes automatically."
    rescue MinutesDrafting::Generate::DraftFailed => error
      if error.run
        redirect_to admin_meeting_minutes_draft_run_path(@meeting, error.run), alert: "The first draft could not be created. The manual minutes workspace is unchanged."
      else
        redirect_to admin_meeting_minutes_path(@meeting), alert: "The first draft could not be created. The manual minutes workspace is unchanged."
      end
    end

    def show
      suggestions = @run.suggestions.includes(
        :minutes_item,
        :minutes_attendance_entry,
        :minutes_section,
        :source_dated_agenda_item,
        :reviewed_by
      )
      @attendance_suggestions_by_entry_id = suggestions
        .select { |suggestion| suggestion.kind == "attendance" }
        .index_by(&:minutes_attendance_entry_id)
      @attendance_entries = @minutes.attendance_entries
      @suggestions = suggestions.reject { |suggestion| suggestion.kind == "attendance" }
      @minutes_people = minutes_people
      if @run.meeting_transcript.source_available?
        @source_document = MinutesDrafting::SourceDocument.new(@run.meeting_transcript.source_text)
      end
    end

    private

    def set_run
      @run = @minutes.draft_runs.find(params[:id])
    end

    def ensure_transcript_source
      return if @meeting.transcript&.source_available?

      redirect_to admin_meeting_minutes_path(@meeting), alert: "Add an available transcript before creating an AI draft."
    end
  end
end
