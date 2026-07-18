module Admin
  class PositionTitlesController < BaseController
    def index
      @position_titles = Organization.first.position_titles.order(:display_order, :name)
    end

    def create
      org = Organization.first
      title = org.position_titles.new(position_title_params)
      title.display_order = (org.position_titles.maximum(:display_order) || 0) + 1
      if title.save
        redirect_to admin_position_titles_path, notice: "Post position added."
      else
        redirect_to admin_position_titles_path, alert: title.errors.full_messages.to_sentence
      end
    end

    def update
      title = PositionTitle.find(params[:id])
      if title.update(position_title_params)
        redirect_to admin_position_titles_path, notice: "Post position updated."
      else
        redirect_to admin_position_titles_path, alert: title.errors.full_messages.to_sentence
      end
    end

    private

    def position_title_params
      params.require(:position_title).permit(:name, :active)
    end
  end
end
