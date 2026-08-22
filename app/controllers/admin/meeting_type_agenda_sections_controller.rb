module Admin
  class MeetingTypeAgendaSectionsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_meeting_type
    before_action :set_section, only: %i[edit update destroy move]

    def new
      @section = @meeting_type.meeting_type_agenda_sections.new(position: next_position)
    end

    def create
      @section = @meeting_type.meeting_type_agenda_sections.new(section_params)
      @meeting_type.with_lock do
        @section.position = next_position
        @section.save!
      end
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Agenda section added."
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      if @section.update(section_params)
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Agenda section updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @section.agenda_items.exists?
        redirect_to edit_admin_meeting_type_path(@meeting_type), alert: "Move or remove this section's agenda items before removing the section."
      elsif @meeting_type.meeting_type_agenda_sections.count == 1
        redirect_to edit_admin_meeting_type_path(@meeting_type), alert: "A meeting type must keep at least one agenda section."
      else
        @section.destroy!
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Agenda section removed."
      end
    end

    def reorder
      MeetingTypeAgendaSection.reorder!(@meeting_type, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end

    def move
      move_section
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Agenda section moved."
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_meeting_type
      @meeting_type = @organization.meeting_types.find(params[:meeting_type_id])
    end

    def set_section
      @section = @meeting_type.meeting_type_agenda_sections.find(params[:id])
    end

    def section_params
      params.require(:meeting_type_agenda_section).permit(:title)
    end

    def next_position
      @meeting_type.meeting_type_agenda_sections.maximum(:position).to_i + 1
    end

    def move_section
      sections = @meeting_type.meeting_type_agenda_sections.ordered.to_a
      current_index = sections.index(@section)
      target_index = params[:direction] == "up" ? current_index - 1 : current_index + 1
      raise ActiveRecord::RecordNotFound unless params[:direction].in?(%w[up down]) && target_index.between?(0, sections.length - 1)

      sections[current_index], sections[target_index] = sections[target_index], sections[current_index]
      MeetingTypeAgendaSection.reorder!(@meeting_type, sections.map(&:id))
    end
  end
end
