module Api
  class DatedAgendaRollCallsController < BaseController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_records
    before_action :ensure_draft_agenda

    def update
      entries = replacement_entries
      @dated_agenda.with_lock do
        @dated_agenda.reload
        raise ActiveRecord::RecordInvalid, @dated_agenda if @dated_agenda.locked_for_editing?

        @item.replace_roll_call_entries!(entries)
      end

      render json: { dated_agenda_item: dated_agenda_item_payload(@item.reload) }
    rescue ActionController::ParameterMissing
      render_error("entries must contain the complete officer list.", status: :unprocessable_entity)
    rescue ActiveRecord::RecordInvalid => e
      record = e.record || @item
      render_validation_error(record, fallback: "Could not save this officer list.")
    end

    def refresh
      @dated_agenda.with_lock do
        @dated_agenda.reload
        raise ActiveRecord::RecordInvalid, @dated_agenda if @dated_agenda.locked_for_editing?

        @item.refresh_roll_call!
      end

      render json: { dated_agenda_item: dated_agenda_item_payload(@item.reload) }
    rescue ActiveRecord::RecordInvalid => e
      record = e.record || @item
      render_validation_error(record, fallback: "Could not refresh this officer list.")
    end

    private

    def set_records
      @dated_agenda = organization.dated_agendas.find(params[:dated_agenda_id])
      @item = @dated_agenda.dated_agenda_items.find(params[:item_id])
      raise ActiveRecord::RecordNotFound unless @item.roll_call?
    end

    def ensure_draft_agenda
      return unless @dated_agenda.locked_for_editing?

      render_error("Reopen this agenda before editing the officer list.", status: :unprocessable_entity)
    end

    def replacement_entries
      submitted = params.require(:entries)
      raise ActionController::ParameterMissing, :entries unless submitted.is_a?(Array)

      people = selectable_people.index_by { |person| person.id.to_s }
      submitted.map do |attributes|
        raise ActionController::ParameterMissing, :entries unless attributes.respond_to?(:permit)

        attributes = attributes.permit(:position_title_id, :person_id)
        raise ActionController::ParameterMissing, :position_title_id if attributes[:position_title_id].blank?

        title = organization.position_titles.where(active: true).find(attributes[:position_title_id])
        person = selected_person(attributes[:person_id], people)
        {
          position_title: title,
          person: person,
          office_name: title.name,
          person_name: person&.full_name
        }
      end
    end

    def selected_person(person_id, people)
      return nil if person_id.blank?

      people.fetch(person_id.to_s) do
        @item.errors.add(:base, "selected officer is not available")
        raise ActiveRecord::RecordInvalid, @item
      end
    end

    def selectable_people
      existing_ids = @item.roll_call_entries.where.not(person_id: nil).select(:person_id)
      Person.directory_visible.or(Person.where(id: existing_ids)).order(:last_name, :first_name, :id)
    end
  end
end
