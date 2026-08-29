module Admin
  class AgendaItemCatalogEntriesController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_entry, only: %i[edit update destroy move]

    def index
      AgendaItemCatalogSeeder.seed_for!(@organization)
      grouped = @organization.agenda_item_catalog_entries.kept.ordered.with_rich_text_commander_notes.group_by(&:category)
      @entries_by_category = AgendaItemCatalogEntry::CATEGORIES.keys.map do |category|
        [ category, grouped.fetch(category, []) ]
      end
    end

    def new
      @entry = @organization.agenda_item_catalog_entries.new(active: true)
    end

    def create
      @entry = @organization.agenda_item_catalog_entries.new(entry_params)
      @entry.position = next_position(@entry.category) if @entry.position.to_i.zero?

      if @entry.save
        redirect_to admin_agenda_item_catalog_entries_path, notice: "Agenda item catalog entry created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      previous_category = @entry.category
      @entry.assign_attributes(entry_params)
      @entry.position = next_position(@entry.category) if @entry.category != previous_category

      if @entry.save
        redirect_to admin_agenda_item_catalog_entries_path, notice: "Agenda item catalog entry updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @entry.remove_from_catalog!
      redirect_to admin_agenda_item_catalog_entries_path, notice: "Agenda catalog item removed."
    end

    def reorder
      category_ids = params.require(:categories).to_unsafe_h
      AgendaItemCatalogEntry.reorder!(@organization, category_ids)
      head :ok
    rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
      head :unprocessable_entity
    end

    def move
      AgendaItemCatalogEntry.move!(@organization, @entry, params[:direction])
      redirect_to admin_agenda_item_catalog_entries_path, notice: "Agenda item moved."
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_agenda_item_catalog_entries_path, alert: "That item cannot move farther in that direction."
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_entry
      @entry = @organization.agenda_item_catalog_entries.kept.find(params[:id])
    end

    def next_position(category)
      @organization.agenda_item_catalog_entries.kept.where(category: category).maximum(:position).to_i + 1
    end

    def entry_params
      params.require(:agenda_item_catalog_entry).permit(
        :title,
        :summary,
        :category,
        :behavior_type,
        :active,
        :body,
        :commander_notes,
        :show_wording_on_agenda,
        :show_wording_in_minutes
      )
    end
  end
end
