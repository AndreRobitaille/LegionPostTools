module Api
  class DatedAgendaItemsController < BaseController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_dated_agenda
    before_action :set_item, only: %i[update destroy]
    before_action :set_section, only: :reorder
    before_action :ensure_draft_agenda

    def create
      @dated_agenda.with_lock do
        @dated_agenda.reload
        ensure_draft_inside_lock!

        section = @dated_agenda.dated_agenda_sections.find(required_section_id)
        attributes = item_params
        @item = @dated_agenda.dated_agenda_items.new(
          attributes.except(:lock_version, :dated_agenda_section_id, :tracked_item_id)
        )
        @item.agenda_section = section
        @item.position = section.agenda_items.maximum(:position).to_i + 1
        @item.active = true
        assign_tracked_item(attributes)
        @item.save!
      end

      render json: { dated_agenda_item: dated_agenda_item_payload(@item) }, status: :created
    rescue ActionController::ParameterMissing
      render_error(
        "dated_agenda_section_id is required.",
        status: :unprocessable_entity,
        details: [ "dated_agenda_section_id is required." ]
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      record = e.try(:record) || @item || @dated_agenda
      render_validation_error(record, fallback: "Could not create this agenda item.")
    end

    def update
      @dated_agenda.with_lock do
        @dated_agenda.reload
        ensure_draft_inside_lock!

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

    def reorder
      @dated_agenda.with_lock do
        @dated_agenda.reload
        ensure_draft_inside_lock!
        @section = @dated_agenda.dated_agenda_sections.find(@section.id)
        DatedAgendaItem.reorder_active_contiguously!(@section, ordered_item_ids)
      end

      render json: { dated_agenda_section: dated_agenda_section_payload(@section.reload) }
    rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
      render_error(
        "Submit every active item in this section exactly once.",
        status: :unprocessable_entity,
        details: [ "dated_agenda_item_ids must be the complete same-section active item order." ]
      )
    rescue ActiveRecord::RecordInvalid => e
      render_validation_error(e.record, fallback: "Could not reorder this agenda section.")
    end

    private

    def set_dated_agenda
      @dated_agenda = organization.dated_agendas.find(params[:dated_agenda_id])
    end

    def set_item
      @item = @dated_agenda.dated_agenda_items.find(params[:id])
    end

    def set_section
      @section = @dated_agenda.dated_agenda_sections.find(params[:section_id])
    end

    def ensure_draft_agenda
      return unless @dated_agenda.locked_for_editing?

      render_error("Reopen this agenda before editing items.", status: :unprocessable_entity)
    end

    def ensure_draft_inside_lock!
      return unless @dated_agenda.locked_for_editing?

      @dated_agenda.errors.add(:base, "Reopen this agenda before editing items.")
      raise ActiveRecord::RecordInvalid, @dated_agenda
    end

    def required_section_id
      section_id = params[:dated_agenda_section_id]
      raise ActionController::ParameterMissing, :dated_agenda_section_id if section_id.blank?

      section_id
    end

    def ordered_item_ids
      ids = params[:dated_agenda_item_ids]
      raise ActionController::ParameterMissing, :dated_agenda_item_ids unless ids.is_a?(Array)

      ids
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
