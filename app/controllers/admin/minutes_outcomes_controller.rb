module Admin
  class MinutesOutcomesController < MinutesDraftController
    before_action :set_outcome, only: %i[edit update destroy move]
    before_action :set_people, only: %i[new create edit update]

    def new
      item = selected_item
      @outcome = item.outcomes.new(position: next_position(item), kind: "motion", disposition: "not_recorded")
    end

    def create
      item = selected_item
      item.with_lock do
        @outcome = item.outcomes.new(normalized_outcome_attributes(outcome_params).merge(position: next_position(item)))
        @outcome.save!
      end
      redirect_to workspace_path, notice: "Outcome added."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ActiveRecord::RecordNotUnique, KeyError
      @outcome ||= unsaved_outcome(item)
      @outcome.errors.add(:base, "The outcome could not be added because the minutes changed. Try again.") if @outcome.errors.empty?
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      @outcome.update!(normalized_outcome_attributes(outcome_params))
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
        :mover_person_id,
        :mover_unidentified,
        :seconder_person_id,
        :seconder_unidentified,
        :disposition,
        :other_disposition,
        :vote_summary,
        :lock_version
      )
    end

    def set_people
      existing_ids = [ @outcome&.mover_person_id, @outcome&.seconder_person_id ]
      @minutes_people = minutes_people(existing_ids)
    end

    def next_position(item)
      item.outcomes.maximum(:position).to_i + 1
    end

    def unsaved_outcome(item)
      attributes = outcome_params.to_h.slice("kind", "text", "vote_summary")
      item.outcomes.new(attributes.merge("disposition" => "not_recorded"))
    end
  end
end
