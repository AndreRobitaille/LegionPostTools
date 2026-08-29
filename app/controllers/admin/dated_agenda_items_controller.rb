module Admin
  class DatedAgendaItemsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_dated_agenda
    before_action :set_item, only: %i[edit update destroy refresh_roll_call]
    before_action :ensure_draft_agenda, only: %i[new create edit update destroy reorder refresh_roll_call]

    def new
      set_agenda_sections
      @agenda_section = selected_agenda_section
      existing_ids = @dated_agenda.dated_agenda_items.pluck(:agenda_item_catalog_entry_id).to_set
      grouped = @organization.agenda_item_catalog_entries.active.ordered.group_by(&:category)
      @entries_by_category = AgendaItemCatalogEntry::CATEGORIES.keys.filter_map do |category|
        entries = grouped[category]
        next if entries.blank?

        [ category, entries.map { |entry| [ entry, existing_ids.include?(entry.id) ] } ]
      end.to_h
    end

    def create
      catalog_entry = @organization.agenda_item_catalog_entries.active.find(params[:agenda_item_catalog_entry_id])
      agenda_section = selected_agenda_section
      @dated_agenda.with_lock do
        return redirect_locked_agenda if @dated_agenda.locked_for_editing?

        DatedAgendaItem.create_from_catalog_entry!(catalog_entry, position: next_position(agenda_section), dated_agenda: @dated_agenda, agenda_section: agenda_section)
      end
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Catalog item added."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to new_admin_dated_agenda_agenda_item_path(@dated_agenda), alert: "Catalog item could not be added."
    end

    def edit
      set_agenda_sections
    end

    def update
      @dated_agenda.with_lock do
        @dated_agenda.reload
        return redirect_locked_agenda if @dated_agenda.locked_for_editing?

        attributes = item_params
        agenda_section_id = attributes.delete(:dated_agenda_section_id)
        agenda_section = agenda_section_id.present? ? @dated_agenda.dated_agenda_sections.find(agenda_section_id) : @item.agenda_section
        @item.position = next_position(agenda_section) if @item.agenda_section != agenda_section
        @item.agenda_section = agenda_section
        @item.update!(attributes)
      end
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda item updated."
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "This agenda item was changed by someone else. Review the latest version before saving."
    rescue ActiveRecord::RecordInvalid
      set_agenda_sections
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @dated_agenda.with_lock do
        return redirect_locked_agenda if @dated_agenda.locked_for_editing?

        @item.destroy!
      end
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda item removed."
    rescue ActiveRecord::RecordNotDestroyed
      redirect_locked_agenda
    end

    def reorder
      agenda_section = selected_agenda_section
      DatedAgendaItem.reorder!(agenda_section, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end

    def refresh_roll_call
      raise ActiveRecord::RecordNotFound unless @item.roll_call?

      @item.refresh_roll_call!
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Officer roll call refreshed for the meeting date."
    rescue ActiveRecord::RecordInvalid
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Officer roll call could not be refreshed."
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_dated_agenda
      @dated_agenda = @organization.dated_agendas.find(params[:dated_agenda_id])
    end

    def set_item
      @item = @dated_agenda.dated_agenda_items.find(params[:id])
    end

    def ensure_draft_agenda
      return unless @dated_agenda.locked_for_editing?

      return head :locked if action_name == "reorder" && request.format.json?

      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Reopen this agenda before editing items."
    end

    def redirect_locked_agenda
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Reopen this agenda before editing items."
    end

    def next_position(agenda_section)
      agenda_section.agenda_items.maximum(:position).to_i + 1
    end

    def item_params
      params.require(:dated_agenda_item).permit(
        :title,
        :summary,
        :body,
        :commander_notes,
        :behavior_type,
        :show_wording_on_agenda,
        :show_wording_in_minutes,
        :lock_version,
        :dated_agenda_section_id
      )
    end

    def set_agenda_sections
      @agenda_sections = @dated_agenda.dated_agenda_sections.ordered
    end

    def selected_agenda_section
      return @dated_agenda.default_agenda_section if params[:dated_agenda_section_id].blank?

      @dated_agenda.dated_agenda_sections.find(params[:dated_agenda_section_id])
    end
  end
end
