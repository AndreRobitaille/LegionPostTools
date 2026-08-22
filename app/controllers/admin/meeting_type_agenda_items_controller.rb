module Admin
  class MeetingTypeAgendaItemsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_meeting_type
    before_action :set_item, only: %i[edit update destroy]

    def new
      set_agenda_sections
      @agenda_section = selected_agenda_section
      existing_ids = @meeting_type.meeting_type_agenda_items.pluck(:agenda_item_catalog_entry_id).to_set
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
      @meeting_type.with_lock do
        MeetingTypeAgendaItem.create_from_catalog_entry!(catalog_entry, position: next_position(agenda_section), meeting_type: @meeting_type, agenda_section: agenda_section)
      end
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Catalog item added."
    rescue ActiveRecord::RecordNotUnique => error
      alert = duplicate_catalog_entry_unique_violation?(error) ? "That catalog item is already in this meeting type." : "Catalog item could not be added."
      redirect_to new_admin_meeting_type_agenda_item_path(@meeting_type), alert: alert
    rescue ActiveRecord::RecordInvalid => error
      alert = duplicate_catalog_entry_error?(error.record) ? "That catalog item is already in this meeting type." : "Catalog item could not be added."
      redirect_to new_admin_meeting_type_agenda_item_path(@meeting_type), alert: alert
    end

    def edit
      set_agenda_sections
    end

    def update
      attributes = item_params
      agenda_section_id = attributes.delete(:meeting_type_agenda_section_id)
      agenda_section = agenda_section_id.present? ? @meeting_type.meeting_type_agenda_sections.find(agenda_section_id) : @item.agenda_section
      @item.position = next_position(agenda_section) if @item.agenda_section != agenda_section
      @item.agenda_section = agenda_section
      if @item.update(attributes)
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Template item updated."
      else
        set_agenda_sections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @item.destroy
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Item removed from the agenda."
    end

    def reorder
      agenda_section = selected_agenda_section
      MeetingTypeAgendaItem.reorder!(agenda_section, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_meeting_type
      @meeting_type = @organization.meeting_types.find(params[:meeting_type_id])
    end

    def set_item
      @item = @meeting_type.meeting_type_agenda_items.find(params[:id])
    end

    def next_position(agenda_section)
      agenda_section.agenda_items.maximum(:position).to_i + 1
    end

    def duplicate_catalog_entry_error?(record)
      record&.errors&.of_kind?(:agenda_item_catalog_entry_id, :taken)
    end

    def duplicate_catalog_entry_unique_violation?(error)
      exception_message = [ error.message, error.cause&.message ].compact.join(" ")
      exception_message.include?("index_mt_agenda_items_on_type_and_catalog_entry") || exception_message.include?("agenda_item_catalog_entry_id")
    end

    def item_params
      params.require(:meeting_type_agenda_item).permit(:title, :summary, :active, :body, :meeting_type_agenda_section_id)
    end

    def set_agenda_sections
      @agenda_sections = @meeting_type.meeting_type_agenda_sections.ordered
    end

    def selected_agenda_section
      return @meeting_type.default_agenda_section if params[:meeting_type_agenda_section_id].blank?

      @meeting_type.meeting_type_agenda_sections.find(params[:meeting_type_agenda_section_id])
    end
  end
end
