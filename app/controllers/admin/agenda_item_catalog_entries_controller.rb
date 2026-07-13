module Admin
  class AgendaItemCatalogEntriesController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_entry, only: %i[edit update]

    def index
      AgendaItemCatalogSeeder.seed_for!(@organization)
      grouped = @organization.agenda_item_catalog_entries.ordered.group_by(&:category)
      @entries_by_category = AgendaItemCatalogEntry::CATEGORIES.keys.filter_map do |category|
        [ category, grouped[category] ] if grouped[category].present?
      end
    end

    def new
      @entry = @organization.agenda_item_catalog_entries.new(active: true)
    end

    def create
      @entry = @organization.agenda_item_catalog_entries.new(entry_params)
      @entry.position = next_position if @entry.position.to_i.zero?

      if @entry.save
        redirect_to admin_agenda_item_catalog_entries_path, notice: "Agenda item catalog entry created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @entry.update(entry_params)
        redirect_to admin_agenda_item_catalog_entries_path, notice: "Agenda item catalog entry updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_entry
      @entry = @organization.agenda_item_catalog_entries.find(params[:id])
    end

    def next_position
      @organization.agenda_item_catalog_entries.maximum(:position).to_i + 1
    end

    def entry_params
      params.require(:agenda_item_catalog_entry).permit(:title, :summary, :category, :behavior_type, :active, :body)
    end
  end
end
