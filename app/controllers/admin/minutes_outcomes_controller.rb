module Admin
  class MinutesOutcomesController < MinutesDraftController
    before_action :set_outcome, only: %i[edit update destroy move]

    def new
      item = selected_item
      @outcome = item.outcomes.new(position: next_position(item), kind: "motion", disposition: "not_recorded")
    end

    def create
      item = selected_item
      item.with_lock do
        @outcome = item.outcomes.new(outcome_params.merge(position: next_position(item)))
        @outcome.save!
      end
      redirect_to workspace_path, notice: "Outcome added."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      @outcome ||= item.outcomes.new(outcome_params)
      @outcome.errors.add(:base, "The outcome could not be added because the minutes changed. Try again.") if @outcome.errors.empty?
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      @outcome.update!(outcome_params)
      redirect_to workspace_path, notice: "Outcome updated."
    rescue ActiveRecord::StaleObjectError
      redirect_to workspace_path, alert: "This outcome changed while you were editing it. Review the latest version."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @outcome.destroy!
      redirect_to workspace_path, notice: "Outcome removed."
    end

    def move
      records = @outcome.minutes_item.outcomes.to_a
      MinutesOutcome.reorder!(@outcome.minutes_item, moved_record_ids(records, @outcome))
      redirect_to workspace_path, notice: "Outcome moved."
    rescue ActiveRecord::RecordNotFound
      redirect_to workspace_path, alert: "That outcome cannot move farther."
    end

    private

    def set_outcome
      @outcome = MinutesOutcome.joins(minutes_item: :minutes_section)
        .where(minutes_sections: { meeting_minutes_id: @minutes.id })
        .find(params[:id])
    end

    def selected_item
      @minutes.items.find(params[:minutes_item_id])
    end

    def outcome_params
      params.require(:minutes_outcome).permit(
        :kind,
        :text,
        :mover_name,
        :seconder_name,
        :disposition,
        :vote_summary,
        :lock_version
      )
    end

    def next_position(item)
      item.outcomes.maximum(:position).to_i + 1
    end
  end
end
