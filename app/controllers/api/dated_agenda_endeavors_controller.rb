module Api
  class DatedAgendaEndeavorsController < BaseController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_dated_agenda

    def create
      if @dated_agenda.locked_for_editing?
        return render_error("Reopen this agenda before adding an Endeavor.", status: :unprocessable_entity)
      end

      endeavor = organization.endeavors.active.find(params[:endeavor_id])
      section = if params[:dated_agenda_section_id].present?
        @dated_agenda.dated_agenda_sections.find(params[:dated_agenda_section_id])
      else
        @dated_agenda.default_agenda_section
      end

      item = @dated_agenda.with_lock do
        DatedAgendaItem.create_from_endeavor!(
          endeavor,
          dated_agenda: @dated_agenda,
          agenda_section: section,
          position: section.agenda_items.maximum(:position).to_i + 1
        )
      end

      render json: {
        dated_agenda_item: {
          id: item.id,
          title: item.title,
          summary: item.summary,
          endeavor_id: item.endeavor_id,
          dated_agenda_section_id: item.dated_agenda_section_id
        }
      }, status: :created
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      if @dated_agenda.reload.locked_for_editing?
        render_error("Reopen this agenda before adding an Endeavor.", status: :unprocessable_entity)
      else
        render_error("That Endeavor is already on this agenda.", status: :unprocessable_entity)
      end
    end

    private

    def set_dated_agenda
      @dated_agenda = organization.dated_agendas.find(params[:dated_agenda_id])
    end
  end
end
