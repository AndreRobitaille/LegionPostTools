module Api
  class EndeavorsController < BaseController
    before_action -> { require_capability("manage_agendas") }, only: %i[create complete reopen]
    before_action :set_endeavor, only: %i[show complete reopen]

    def index
      items = organization.endeavors.includes(:meeting_body).order(:status, :title).to_a
      upcoming_agenda_ids = upcoming_agenda_ids_by_endeavor_id(items)
      render json: {
        endeavors: items.map do |item|
          endeavor_summary(item, upcoming_agenda_ids: upcoming_agenda_ids.fetch(item.id, []))
        end
      }
    end

    def show
      render json: { endeavor: endeavor_detail(@endeavor) }
    end

    def create
      endeavor = organization.endeavors.new(endeavor_params)
      endeavor.created_by = current_user

      if endeavor.save
        render json: { endeavor: endeavor_detail(endeavor) }, status: :created
      else
        render_error(endeavor.errors.full_messages.to_sentence, status: :unprocessable_entity, details: endeavor.errors.full_messages)
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
      @endeavor.complete!(current_user)
      render json: { endeavor: endeavor_summary(@endeavor) }
    rescue ActiveRecord::RecordInvalid
      render_error(@endeavor.errors.full_messages.to_sentence, status: :unprocessable_entity)
    end

    def reopen
      @endeavor.reopen!
      render json: { endeavor: endeavor_summary(@endeavor) }
    rescue ActiveRecord::RecordInvalid
      render_error(@endeavor.errors.full_messages.to_sentence, status: :unprocessable_entity)
    end

    private

    def set_endeavor
      @endeavor = organization.endeavors.find(params[:id])
    end

    def endeavor_params
      permitted = params.permit(:title, :summary, :details, :importance, :raise_by_on, :meeting_body_id)
      if permitted[:raise_by_on].present?
        permitted[:raise_by_on] = Date.iso8601(permitted[:raise_by_on].to_s)
      end
      permitted
    end

    def upcoming_agenda_ids_for(item)
      item.dated_agendas.merge(DatedAgenda.upcoming).ids
    end

    def upcoming_agenda_ids_by_endeavor_id(items)
      ids = items.map(&:id)
      return {} if ids.empty?

      DatedAgendaItem.joins(:dated_agenda)
        .where(endeavor_id: ids)
        .where("dated_agendas.starts_at >= ?", Time.zone.today.beginning_of_day)
        .order("dated_agendas.starts_at ASC", "dated_agendas.title ASC")
        .pluck(:endeavor_id, :dated_agenda_id)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last) }
    end

    def endeavor_summary(item, upcoming_agenda_ids: upcoming_agenda_ids_for(item))
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

    def endeavor_detail(item)
      endeavor_summary(item).merge(details: item.details.to_plain_text.presence || item.details.to_s)
    end
  end
end
