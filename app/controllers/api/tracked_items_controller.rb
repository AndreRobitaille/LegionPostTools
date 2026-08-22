module Api
  class TrackedItemsController < BaseController
    before_action -> { require_capability("manage_agendas") }, only: %i[create complete reopen]
    before_action :set_tracked_item, only: %i[show complete reopen]

    def index
      items = organization.tracked_items.includes(:meeting_body).order(:status, :title).to_a
      upcoming_agenda_ids = upcoming_agenda_ids_by_tracked_item_id(items)
      render json: {
        tracked_items: items.map do |item|
          tracked_item_summary(item, upcoming_agenda_ids: upcoming_agenda_ids.fetch(item.id, []))
        end
      }
    end

    def show
      render json: { tracked_item: tracked_item_detail(@tracked_item) }
    end

    def create
      tracked_item = organization.tracked_items.new(tracked_item_params)
      tracked_item.created_by = current_user

      if tracked_item.save
        render json: { tracked_item: tracked_item_detail(tracked_item) }, status: :created
      else
        render_error(tracked_item.errors.full_messages.to_sentence, status: :unprocessable_entity, details: tracked_item.errors.full_messages)
      end
    rescue Date::Error
      message = "raise_by_on must be an ISO 8601 date in YYYY-MM-DD form."
      render_error(
        message,
        status: :unprocessable_entity,
        details: [ message ]
      )
    end

    def complete
      @tracked_item.complete!(current_user)
      render json: { tracked_item: tracked_item_summary(@tracked_item) }
    rescue ActiveRecord::RecordInvalid
      render_error(@tracked_item.errors.full_messages.to_sentence, status: :unprocessable_entity)
    end

    def reopen
      @tracked_item.reopen!
      render json: { tracked_item: tracked_item_summary(@tracked_item) }
    rescue ActiveRecord::RecordInvalid
      render_error(@tracked_item.errors.full_messages.to_sentence, status: :unprocessable_entity)
    end

    private

    def set_tracked_item
      @tracked_item = organization.tracked_items.find(params[:id])
    end

    def tracked_item_params
      permitted = params.permit(:title, :summary, :details, :importance, :raise_by_on, :meeting_body_id)
      if permitted[:raise_by_on].present?
        permitted[:raise_by_on] = Date.iso8601(permitted[:raise_by_on].to_s)
      end
      permitted
    end

    def upcoming_agenda_ids_for(item)
      item.dated_agendas.merge(DatedAgenda.upcoming).ids
    end

    def upcoming_agenda_ids_by_tracked_item_id(items)
      ids = items.map(&:id)
      return {} if ids.empty?

      DatedAgendaItem.joins(:dated_agenda)
        .where(tracked_item_id: ids)
        .where("dated_agendas.starts_at >= ?", Time.zone.today.beginning_of_day)
        .order("dated_agendas.starts_at ASC", "dated_agendas.title ASC")
        .pluck(:tracked_item_id, :dated_agenda_id)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last) }
    end

    def tracked_item_summary(item, upcoming_agenda_ids: upcoming_agenda_ids_for(item))
      {
        id: item.id,
        title: item.title,
        summary: item.summary,
        status: item.status,
        importance: item.importance,
        raise_by_on: item.raise_by_on&.iso8601,
        meeting_body: meeting_body_payload(item.meeting_body),
        upcoming_agenda_ids: upcoming_agenda_ids
      }
    end

    def tracked_item_detail(item)
      tracked_item_summary(item).merge(details: item.details.to_plain_text.presence || item.details.to_s)
    end
  end
end
