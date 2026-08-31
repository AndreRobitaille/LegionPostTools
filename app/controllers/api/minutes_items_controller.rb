module Api
  class MinutesItemsController < MinutesBaseController
    before_action :set_item, only: %i[update destroy]

    def create
      section = @minutes.sections.find(params.require(:minutes_section_id))
      section.with_lock do
        attributes = item_params.to_h.symbolize_keys.except(:minutes_section_id)
        attributes[:behavior_type] ||= "business_item"
        @item = section.items.create!(attributes.merge(position: section.items.maximum(:position).to_i + 1))
      end
      render json: { item: minutes_item_payload(@item) }, status: :created
    rescue ActionController::ParameterMissing => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      record = error.respond_to?(:record) ? error.record : @item
      render_validation_error(record || @minutes, fallback: "The minutes item could not be added.")
    end

    def update
      attributes = item_params.to_h.symbolize_keys
      section_id = attributes.delete(:minutes_section_id)
      section = section_id.present? ? @minutes.sections.find(section_id) : @item.minutes_section

      @item.transaction do
        if @item.minutes_section != section
          @item.minutes_section = section
          @item.position = section.items.maximum(:position).to_i + 1
        end
        @item.update!(attributes)
      end
      render json: { item: minutes_item_payload(@item.reload) }
    rescue ActiveRecord::StaleObjectError
      render_error("This item changed while you were editing it. Fetch it again before saving.", status: :conflict)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      record = error.respond_to?(:record) ? error.record : @item
      render_validation_error(record || @item, fallback: "The minutes item could not be updated.")
    end

    def destroy
      deleted = minutes_item_payload(@item)
      @item.destroy!
      render json: { deleted_item: deleted }
    end

    def reorder
      section = @minutes.sections.find(params[:section_id])
      section.with_lock do
        ids = exact_order_ids!(section.items)
        MinutesItem.reorder!(section, ids)
      end
      render json: { items: section.items.reload.map { |item| minutes_item_payload(item) } }
    rescue ArgumentError => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    end

    private

    def set_item
      @item = @minutes.items.find(params[:id])
    end

    def item_params
      params.permit(:minutes_section_id, :title, :behavior_type, :body, :endeavor_id, :lock_version)
    end
  end
end
