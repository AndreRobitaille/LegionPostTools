module Admin
  class PositionTitlesController < BaseController
    def index
      @position_titles = Organization.first.position_titles.order(:display_order, :name)
    end

    def create
      title = Organization.first.position_titles.new(position_title_params)
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
      params.require(:position_title).permit(:name, :display_order, :active)
    end
  end
end
