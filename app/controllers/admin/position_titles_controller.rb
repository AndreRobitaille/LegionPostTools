module Admin
  class PositionTitlesController < BaseController
    before_action :set_position_title, only: %i[edit update]

    def index
      @position_titles = Organization.first.position_titles.includes(:position_capability_grants).order(:display_order, :name)
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

    def edit
    end

    def update
      if @position_title.update(position_title_params)
        redirect_to admin_position_titles_path, notice: "Post position updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def reorder
      PositionTitle.reorder!(Organization.first, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end

    private

    def set_position_title
      @position_title = Organization.first!.position_titles.find(params[:id])
    end

    def position_title_params
      params.require(:position_title).permit(:name, :active, :grants_full_membership_access, :contact_description, :contact_examples_text, :website_officer_listing)
    end
  end
end
