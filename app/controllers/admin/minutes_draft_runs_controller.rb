module Admin
  class MinutesDraftRunsController < MinutesDraftController
    before_action :set_run, only: %i[show status]
    before_action :ensure_transcript_source, only: %i[new create]

    def new
      @transcript = @meeting.transcript
    end

    def create
      run = MinutesDrafting::Generate.prepare(minutes: @minutes, requester: current_user)
      job = MinutesDraftGenerationJob.perform_later(run)

      unless job.successfully_enqueued?
        mark_enqueue_failed!(run)
        return redirect_to admin_meeting_minutes_draft_run_path(@meeting, run), alert: "The draft worker could not be started. The manual minutes workspace is unchanged."
      end

      redirect_to admin_meeting_minutes_draft_run_path(@meeting, run), notice: "Drafting started. You may safely leave this page while OpenAI works."
    rescue MinutesDrafting::Generate::DraftFailed => error
      if error.run
        redirect_to admin_meeting_minutes_draft_run_path(@meeting, error.run), alert: "The first draft could not be created. The manual minutes workspace is unchanged."
      else
        redirect_to admin_meeting_minutes_path(@meeting), alert: "The first draft could not be created. The manual minutes workspace is unchanged."
      end
    end

    def show
      return unless @run.succeeded?

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

    def status
      expires_now
      render json: { status: @run.status, updated_at: @run.updated_at.iso8601 }
    end

    private

    def set_run
      @run = @minutes.draft_runs.find(params[:id])
    end

    def ensure_transcript_source
      return if @meeting.transcript&.source_available?

      redirect_to admin_meeting_minutes_path(@meeting), alert: "Add an available transcript before creating an AI draft."
    end

    def mark_enqueue_failed!(run)
      run.update_columns(
        status: "failed",
        error_category: "queue_error",
        completed_at: Time.current,
        updated_at: Time.current
      )
    end
  end
end
