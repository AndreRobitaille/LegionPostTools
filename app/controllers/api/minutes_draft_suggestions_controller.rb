module Api
  class MinutesDraftSuggestionsController < MinutesBaseController
    before_action :set_run_and_suggestion

    def use
      review!("use", review_edits(for_use: true))
      render_review
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, KeyError, ArgumentError => error
      render_review_error(error)
    end

    def edit
      review!("edit", review_edits(for_use: false))
      render_review
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, KeyError, ArgumentError => error
      render_review_error(error)
    end

    def discard
      review!("discard", {})
      render_review
    rescue ActiveRecord::RecordInvalid => error
      render_review_error(error)
    end

    private

    def set_run_and_suggestion
      @run = @minutes.draft_runs.find(params[:draft_run_id])
      @suggestion = @run.suggestions.find(params[:id])
    end

    def review!(action, edits)
      MinutesDrafting::ReviewSuggestion.call(
        suggestion: @suggestion,
        reviewer: current_user,
        action: action,
        edits: edits
      )
    end

    def review_edits(for_use:)
      return normalize_outcome_attributes(suggestion_params) if @suggestion.kind == "outcome"
      return {} if for_use

      suggestion_params.to_h
    end

    def suggestion_params
      params.permit(
        :title,
        :body,
        :kind,
        :text,
        :disposition,
        :other_disposition,
        :mover_person_id,
        :mover_unidentified,
        :seconder_person_id,
        :seconder_unidentified,
        :vote_summary,
        :status,
        :endeavor_id
      )
    end

    def render_review
      render json: {
        suggestion: minutes_draft_suggestion_payload(@suggestion.reload),
        minutes: minutes_detail_payload(@minutes.reload)
      }
    end

    def render_review_error(error)
      details = @suggestion.errors.full_messages.presence || [ error.message ]
      render_error(
        details.to_sentence.presence || "That suggestion could not be reviewed.",
        status: :unprocessable_entity,
        details: details
      )
    end
  end
end
