module Api
  class MinutesOutcomesController < MinutesBaseController
    before_action :set_outcome, only: %i[update destroy]

    def create
      item = @minutes.items.find(params.require(:minutes_item_id))
      item.with_lock do
        attributes = normalize_outcome_attributes(outcome_params)
        attributes[:kind] ||= "motion"
        @outcome = item.outcomes.create!(attributes.merge(position: item.outcomes.maximum(:position).to_i + 1))
      end
      render json: { outcome: minutes_outcome_payload(@outcome) }, status: :created
    rescue ActionController::ParameterMissing, ArgumentError => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      record = error.respond_to?(:record) ? error.record : @outcome
      render_validation_error(record || @minutes, fallback: "The outcome could not be added.")
    end

    def update
      @outcome.update!(normalize_outcome_attributes(outcome_params, outcome: @outcome))
      render json: { outcome: minutes_outcome_payload(@outcome.reload) }
    rescue ArgumentError => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    rescue ActiveRecord::StaleObjectError
      render_error("This outcome changed while you were editing it. Fetch it again before saving.", status: :conflict)
    rescue ActiveRecord::RecordInvalid
      render_validation_error(@outcome, fallback: "The outcome could not be updated.")
    end

    def destroy
      deleted = minutes_outcome_payload(@outcome)
      @outcome.destroy!
      render json: { deleted_outcome: deleted }
    end

    def reorder
      item = @minutes.items.find(params[:item_id])
      item.with_lock do
        ids = exact_order_ids!(item.outcomes)
        MinutesOutcome.reorder!(item, ids)
      end
      render json: { outcomes: item.outcomes.reload.map { |outcome| minutes_outcome_payload(outcome) } }
    rescue ArgumentError => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    end

    private

    def set_outcome
      @outcome = MinutesOutcome.joins(minutes_item: :minutes_section)
        .where(minutes_sections: { meeting_minutes_id: @minutes.id })
        .find(params[:id])
    end

    def outcome_params
      params.permit(
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
  end
end
