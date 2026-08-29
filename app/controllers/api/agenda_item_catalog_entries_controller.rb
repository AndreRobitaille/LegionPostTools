module Api
  class AgendaItemCatalogEntriesController < BaseController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_entry, only: %i[update destroy]

    def index
      render_catalog
    end

    def create
      entry = organization.agenda_item_catalog_entries.new(entry_params)
      entry.position = next_position(entry.category) if entry.position.to_i.zero?
      entry.save!

      render json: { agenda_item_catalog_entry: agenda_catalog_entry_payload(entry) }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render_validation_error(e.record, fallback: "Could not save this catalog item.")
    end

    def update
      previous_category = @entry.category
      @entry.assign_attributes(entry_params)
      @entry.position = next_position(@entry.category) if @entry.category != previous_category
      @entry.save!

      render json: { agenda_item_catalog_entry: agenda_catalog_entry_payload(@entry) }
    rescue ActiveRecord::RecordInvalid => e
      render_validation_error(e.record, fallback: "Could not save this catalog item.")
    end

    def reorder
      AgendaItemCatalogEntry.reorder!(organization, params.require(:categories).to_unsafe_h)
      render_catalog
    rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
      render_error("Submit every kept catalog item exactly once under a valid category.", status: :unprocessable_entity)
    end

    def destroy
      @entry.remove_from_catalog!
      render json: { removed_agenda_item_catalog_entry: agenda_catalog_entry_payload(@entry) }
    end

    private

    def set_entry
      @entry = organization.agenda_item_catalog_entries.kept.find(params[:id])
    end

    def entry_params
      params.permit(
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

    def next_position(category)
      organization.agenda_item_catalog_entries.kept.where(category: category).maximum(:position).to_i + 1
    end

    def render_catalog
      entries = organization.agenda_item_catalog_entries.kept
        .with_rich_text_body
        .with_rich_text_commander_notes
        .to_a
        .sort_by do |entry|
          category_index = AgendaItemCatalogEntry::CATEGORIES.keys.index(entry.category) || AgendaItemCatalogEntry::CATEGORIES.length
          [ category_index, entry.position, entry.title ]
        end
      render json: {
        categories: AgendaItemCatalogEntry::CATEGORIES.map { |key, label| { key: key, label: label } },
        agenda_item_catalog_entries: entries.map { |entry| agenda_catalog_entry_payload(entry) }
      }
    end
  end
end
