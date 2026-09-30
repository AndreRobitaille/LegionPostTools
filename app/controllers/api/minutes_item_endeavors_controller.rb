module Api
  class MinutesItemEndeavorsController < MinutesBaseController
    before_action :set_item
    before_action :require_creation_permission

    def create
      endeavor = MinutesEndeavors::Confirm.call(
        item: @item,
        reviewer: current_user,
        attributes: params.permit(:endeavor_action, :title, :body, :endeavor_id, :lock_version)
      )
      render json: {
        item: minutes_item_payload(@item.reload),
        endeavor: { id: endeavor.id, title: endeavor.title, summary: endeavor.summary, status: endeavor.status }
      }, status: params[:endeavor_action] == "create" ? :created : :ok
    rescue ActiveRecord::StaleObjectError
      render_error("This item changed while you were reviewing it. Fetch it again before confirming.", status: :conflict)
    rescue ActiveRecord::RecordInvalid => error
      render_validation_error(error.record, fallback: "The Endeavor could not be confirmed.")
    end

    private

    def set_item
      @item = @minutes.items.find(params[:item_id])
    end

    def require_creation_permission
      require_capability("manage_agendas") if params[:endeavor_action] == "create"
    end
  end
end
