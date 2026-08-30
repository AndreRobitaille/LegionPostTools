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
      redirect_to run_path, notice: "Suggestion added to the working minutes."
    rescue ActiveRecord::RecordInvalid, KeyError
      redirect_to run_path, alert: "That suggestion could not be used. Review the current minutes and try again."
    end

    def discard
      review!("discard")
      redirect_to run_path, notice: "Suggestion discarded."
    rescue ActiveRecord::RecordInvalid
      redirect_to run_path, alert: "That suggestion has already been reviewed."
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
  end
end
