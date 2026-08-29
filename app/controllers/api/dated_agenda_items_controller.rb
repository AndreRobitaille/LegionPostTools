module Api
  class DatedAgendaItemsController < BaseController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_records
    before_action :ensure_draft_agenda

    def update
      @dated_agenda.with_lock do
        @dated_agenda.reload
        raise ActiveRecord::RecordInvalid, @dated_agenda if @dated_agenda.locked_for_editing?

        attributes = item_params
        assign_section(attributes)
        assign_tracked_item(attributes)
        @item.update!(attributes)
      end

      render json: { dated_agenda_item: dated_agenda_item_payload(@item) }
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => e
      record = e.try(:record) || @item
      render_validation_error(record, fallback: "Could not update this agenda item.")
    end

    def destroy
      deleted = dated_agenda_item_payload(@item)
      @dated_agenda.with_lock { @item.destroy! }
      render json: { removed_dated_agenda_item: deleted }
    rescue ActiveRecord::RecordNotDestroyed => e
      render_validation_error(e.record, fallback: "Could not remove this agenda item.")
    end

    private

    def set_records
      @dated_agenda = organization.dated_agendas.find(params[:dated_agenda_id])
      @item = @dated_agenda.dated_agenda_items.find(params[:id])
    end

    def ensure_draft_agenda
      return unless @dated_agenda.locked_for_editing?

      render_error("Reopen this agenda before editing items.", status: :unprocessable_entity)
    end

    def item_params
      params.permit(
        :title,
        :summary,
        :body,
        :commander_notes,
        :behavior_type,
        :show_wording_on_agenda,
        :show_wording_in_minutes,
        :lock_version,
        :dated_agenda_section_id,
        :tracked_item_id
      )
    end

    def assign_section(attributes)
      return unless attributes.key?(:dated_agenda_section_id)

      section_id = attributes.delete(:dated_agenda_section_id)
      section = @dated_agenda.dated_agenda_sections.find(section_id)
      return if section == @item.agenda_section

      @item.agenda_section = section
      @item.position = section.agenda_items.maximum(:position).to_i + 1
    end

    def assign_tracked_item(attributes)
      return unless attributes.key?(:tracked_item_id)

      tracked_item_id = attributes.delete(:tracked_item_id)
      @item.tracked_item = tracked_item_id.present? ? organization.tracked_items.find(tracked_item_id) : nil
    end
  end
end
