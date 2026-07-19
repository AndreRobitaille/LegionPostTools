module Admin
  class MeetingTypesController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_meeting_type, only: %i[edit update destroy reset_agenda]

    def index
      @meeting_types = @organization.meeting_types.ordered.includes(:meeting_type_agenda_items)
      @default_meeting_types_missing = MeetingTypeTemplateSeeder.defaults_missing?(@organization)
    end

    def new
      @meeting_type = @organization.meeting_types.new(active: true)
    end

    def create
      @meeting_type = @organization.meeting_types.new(meeting_type_params)

      @organization.with_lock do
        @meeting_type.position = next_position if @meeting_type.position.to_i.zero?
        @meeting_type.save
      end

      if @meeting_type.persisted?
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Meeting type created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def seed_defaults
      MeetingTypeTemplateSeeder.seed_for!(@organization)
      redirect_to admin_meeting_types_path, notice: "Default meeting types seeded."
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

    def destroy
      @meeting_type.destroy
      redirect_to admin_meeting_types_path, notice: "Meeting type deleted."
    end

    def reorder
      MeetingType.reorder!(@organization, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end

    def reset_defaults
      MeetingTypeTemplateSeeder.reset_for!(@organization)
      redirect_to admin_meeting_types_path, notice: "Suggested meeting types reset."
    end

    def reset_agenda
      MeetingTypeTemplateSeeder.reset_agenda_for!(@meeting_type)
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Agenda reset to the default items."
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
