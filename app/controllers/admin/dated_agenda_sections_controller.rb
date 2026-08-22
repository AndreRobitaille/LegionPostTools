module Admin
  class DatedAgendaSectionsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_dated_agenda
    before_action :ensure_draft_agenda
    before_action :set_section, only: %i[edit update destroy move]

    def new
      @section = @dated_agenda.dated_agenda_sections.new(position: next_position)
    end

    def create
      @section = @dated_agenda.dated_agenda_sections.new(section_params)
      @dated_agenda.with_lock do
        @dated_agenda.reload
        return redirect_locked_agenda if @dated_agenda.locked_for_editing?

        @section.position = next_position
        @section.save!
      end
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda section added."
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      @dated_agenda.with_lock do
        @dated_agenda.reload
        return redirect_locked_agenda if @dated_agenda.locked_for_editing?

        @section.update!(section_params)
      end
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda section updated."
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "This section was changed by someone else. Review the latest version before saving."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      if @section.agenda_items.exists?
        redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Move or remove this section's agenda items before removing the section."
      elsif @dated_agenda.dated_agenda_sections.count == 1
        redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "An agenda must keep at least one section."
      else
        @section.destroy!
        redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda section removed."
      end
    end

    def reorder
      DatedAgendaSection.reorder!(@dated_agenda, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end

    def move
      move_section
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda section moved."
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_dated_agenda
      @dated_agenda = @organization.dated_agendas.find(params[:dated_agenda_id])
    end

    def set_section
      @section = @dated_agenda.dated_agenda_sections.find(params[:id])
    end

    def ensure_draft_agenda
      return unless @dated_agenda.locked_for_editing?

      return head :locked if action_name == "reorder" && request.format.json?

      redirect_locked_agenda
    end

    def redirect_locked_agenda
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Reopen this agenda before editing sections."
    end

    def section_params
      params.require(:dated_agenda_section).permit(:title, :lock_version)
    end

    def next_position
      @dated_agenda.dated_agenda_sections.maximum(:position).to_i + 1
    end

    def move_section
      sections = @dated_agenda.dated_agenda_sections.ordered.to_a
      current_index = sections.index(@section)
      target_index = params[:direction] == "up" ? current_index - 1 : current_index + 1
      raise ActiveRecord::RecordNotFound unless params[:direction].in?(%w[up down]) && target_index.between?(0, sections.length - 1)

      sections[current_index], sections[target_index] = sections[target_index], sections[current_index]
      DatedAgendaSection.reorder!(@dated_agenda, sections.map(&:id))
    end
  end
end
