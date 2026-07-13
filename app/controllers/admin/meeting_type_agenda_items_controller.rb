module Admin
  class MeetingTypeAgendaItemsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_meeting_type
    before_action :set_item, only: %i[edit update destroy move]

    def new
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
      MeetingTypeAgendaItem.create_from_catalog_entry!(catalog_entry, position: next_position, meeting_type: @meeting_type)
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Catalog item added."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      # The uniqueness validation and the DB unique index both guard against a
      # catalog item being added to a meeting type twice; a double-submit lands here.
      redirect_to new_admin_meeting_type_agenda_item_path(@meeting_type), alert: "That catalog item is already in this meeting type."
    end

    def edit; end

    def update
      if @item.update(item_params)
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Template item updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @item.seeded?
        # Seeded items are kept (marked inactive) so a reseed doesn't recreate them.
        @item.update!(active: false)
        notice = "Template item deactivated for this meeting type."
      else
        @item.destroy
        notice = "Template item removed."
      end
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: notice
    end

    def move
      neighbor = case params[:direction]
      when "up" then @meeting_type.meeting_type_agenda_items.where("position < ?", @item.position).ordered.last
      when "down" then @meeting_type.meeting_type_agenda_items.where("position > ?", @item.position).ordered.first
      end
      if neighbor.present?
        current_position = @item.position
        @item.update!(position: neighbor.position)
        neighbor.update!(position: current_position)
      end
      redirect_to edit_admin_meeting_type_path(@meeting_type)
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

    def next_position
      @meeting_type.meeting_type_agenda_items.maximum(:position).to_i + 1
    end

    def item_params
      params.require(:meeting_type_agenda_item).permit(:title, :summary, :active, :body)
    end
  end
end
