module Admin
  class MinutesDraftSuggestionsController < MinutesDraftController
    before_action :set_suggestion
    before_action :set_endeavors, only: %i[edit update]

    def edit; end

    def update
      review!("edit", suggestion_params)
      redirect_to run_path, notice: "Edited suggestion added to the working minutes."
    rescue ActiveRecord::RecordInvalid, KeyError
      @suggestion.errors.add(:base, "Review the proposed wording and required facts.") if @suggestion.errors.empty?
      render :edit, status: :unprocessable_entity
    end

    def use
      review!("use")
      render_review_result(notice: "Suggestion added to the working minutes.")
    rescue ActiveRecord::RecordInvalid, KeyError
      render_review_result(
        alert: "That suggestion could not be used. Review the current minutes and try again.",
        status: :unprocessable_entity
      )
    end

    def discard
      review!("discard")
      render_review_result(notice: "Suggestion discarded.")
    rescue ActiveRecord::RecordInvalid
      render_review_result(alert: "That suggestion has already been reviewed.", status: :unprocessable_entity)
    end

    private

    def set_suggestion
      @suggestion = MinutesDraftSuggestion.joins(:minutes_draft_run)
        .where(minutes_draft_runs: { meeting_minutes_id: @minutes.id })
        .find(params[:id])
    end

    def review!(action, edits = {})
      MinutesDrafting::ReviewSuggestion.call(
        suggestion: @suggestion,
        reviewer: current_user,
        action: action,
        edits: edits
      )
    end

    def suggestion_params
      params.fetch(:minutes_draft_suggestion, {}).permit(
        :title,
        :body,
        :kind,
        :text,
        :disposition,
        :mover_name,
        :seconder_name,
        :vote_summary,
        :status,
        :endeavor_id
      )
    end

    def set_endeavors
      @endeavors = @organization.endeavors.order(:title)
    end

    def run_path
      admin_meeting_minutes_draft_run_path(@meeting, @suggestion.minutes_draft_run)
    end

    def render_review_result(notice: nil, alert: nil, status: :ok)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              ActionView::RecordIdentifier.dom_id(@suggestion, :review),
              partial: "admin/minutes_draft_runs/suggestion_card",
              locals: {
                suggestion: @suggestion.reload,
                meeting: @meeting,
                source_document: source_document,
                inline_error: alert
              }
            ),
            turbo_stream.replace(
              "ai_review_counter",
              partial: "admin/minutes_draft_runs/review_counter",
              locals: { run: @suggestion.minutes_draft_run }
            )
          ], status: status
        end
        format.html do
          redirect_to run_path, notice: notice, alert: alert
        end
      end
    end

    def source_document
      transcript = @suggestion.minutes_draft_run.meeting_transcript
      MinutesDrafting::SourceDocument.new(transcript.source_text) if transcript.source_available?
    end
  end
end
