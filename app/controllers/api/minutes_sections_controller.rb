module Api
  class MinutesSectionsController < MinutesBaseController
    before_action :set_section, only: %i[update destroy]

    def create
      @minutes.with_lock do
        @section = @minutes.sections.create!(
          section_params.merge(position: @minutes.sections.maximum(:position).to_i + 1)
        )
      end
      render json: { section: minutes_section_payload(@section) }, status: :created
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      record = error.respond_to?(:record) ? error.record : @section
      render_validation_error(record || @minutes, fallback: "The minutes section could not be added.")
    end

    def update
      @section.update!(section_params)
      render json: { section: minutes_section_payload(@section.reload) }
    rescue ActiveRecord::StaleObjectError
      render_error("This section changed while you were editing it. Fetch it again before saving.", status: :conflict)
    rescue ActiveRecord::RecordInvalid
      render_validation_error(@section, fallback: "The minutes section could not be updated.")
    end

    def destroy
      if @section.items.exists?
        return render_error("Move or remove this section's items before removing the section.", status: :unprocessable_entity)
      end
      if @minutes.sections.count == 1
        return render_error("Minutes must keep at least one section.", status: :unprocessable_entity)
      end

      deleted = minutes_section_payload(@section)
      @section.destroy!
      render json: { deleted_section: deleted }
    end

    def reorder
      @minutes.with_lock do
        ids = exact_order_ids!(@minutes.sections)
        MinutesSection.reorder!(@minutes, ids)
      end
      render json: { sections: @minutes.sections.reload.map { |section| minutes_section_payload(section) } }
    rescue ArgumentError => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    end

    private

    def set_section
      @section = @minutes.sections.find(params[:id])
    end

    def section_params
      params.permit(:title, :lock_version)
    end
  end
end
