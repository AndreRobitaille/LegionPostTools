module Admin
  class MeetingTypesController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_meeting_type, only: %i[edit update]

    def index
      MeetingTypeTemplateSeeder.seed_for!(@organization)
      @meeting_types = @organization.meeting_types.ordered.includes(:meeting_type_agenda_items)
    end

    def new
      @meeting_type = @organization.meeting_types.new(active: true)
    end

    def create
      @meeting_type = @organization.meeting_types.new(meeting_type_params)
      @meeting_type.position = next_position if @meeting_type.position.to_i.zero?

      if @meeting_type.save
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Meeting type created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @template_items = @meeting_type.meeting_type_agenda_items.ordered
    end

    def update
      if @meeting_type.update(meeting_type_params)
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Meeting type updated."
      else
        @template_items = @meeting_type.meeting_type_agenda_items.ordered
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_meeting_type
      @meeting_type = @organization.meeting_types.find(params[:id])
    end

    def meeting_type_params
      params.require(:meeting_type).permit(:name, :active)
    end

    def next_position
      @organization.meeting_types.maximum(:position).to_i + 1
    end
  end
end
