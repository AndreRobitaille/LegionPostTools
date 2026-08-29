module Api
  class PositionTitlesController < BaseController
    before_action -> { require_capability("manage_agendas") }

    def index
      titles = organization.position_titles.where(active: true).order(:display_order, :name)
      render json: {
        position_titles: titles.map do |title|
          {
            id: title.id,
            name: title.name,
            display_order: title.display_order,
            required_by_default: title.required_by_default?
          }
        end
      }
    end
  end
end
