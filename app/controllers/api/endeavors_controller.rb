module Api
  class EndeavorsController < BaseController
    include Concerns::ActivityContract

    before_action -> { require_capability("manage_agendas") }, only: %i[create update complete reopen]
    before_action :set_endeavor, only: %i[show update complete reopen]

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
      render json: { endeavor: endeavor_detail(@endeavor).merge(history: EndeavorHistory::Serialization.member(@endeavor, before: params[:before])) }
    end

    def create
      endeavor = organization.endeavors.new(endeavor_params)
      endeavor.created_by = current_user

      if endeavor.save
        render json: { endeavor: endeavor_detail(endeavor) }, status: :created
      else
        render_error(endeavor.errors.full_messages.to_sentence, status: :unprocessable_entity, details: endeavor.errors.full_messages)
      end
    end

    def update
      @endeavor.lock_version = activity_lock_version!(@endeavor)
      @endeavor.update!(endeavor_params)
      render json: { endeavor: endeavor_detail(@endeavor) }
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
      permitted = params.permit(:title, :summary, :details, :importance, :due_on, :raise_by_on, :meeting_body_id)
      date_key = permitted.key?(:due_on) ? :due_on : :raise_by_on
      permitted.delete(:raise_by_on) if date_key == :due_on
      permitted[date_key] = activity_date(permitted[date_key], field: date_key) if permitted.key?(date_key)
      if permitted[:meeting_body_id].present?
        organization.meeting_bodies.find(permitted[:meeting_body_id])
      end
      permitted
    end

    def upcoming_agenda_ids_for(item)
      scope = item.dated_agendas
      scope = scope.where(status: "published") unless current_user.can?("manage_agendas")
      scope.joins(:meeting).merge(Meeting.upcoming).ids
    end

    def upcoming_agenda_ids_by_endeavor_id(items)
      ids = items.map(&:id)
      return {} if ids.empty?

      scope = DatedAgendaItem.joins(dated_agenda: :meeting).where(endeavor_id: ids)
      scope = scope.where(dated_agendas: { status: "published" }) unless current_user.can?("manage_agendas")
      scope
        .merge(Meeting.upcoming)
        .order("meetings.starts_at ASC", "meetings.title ASC")
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
        lock_version: item.lock_version,
        importance: item.importance,
        due_on: item.due_on&.iso8601,
        raise_by_on: item.due_on&.iso8601,
        meeting_body: meeting_body_payload(item.meeting_body),
        upcoming_agenda_ids: upcoming_agenda_ids
      }
    end

    def endeavor_detail(item)
      endeavor_summary(item).merge(
        details: item.details.to_plain_text.presence || item.details.to_s,
        tasks_path: "/api/endeavors/#{item.id}/tasks",
        calendar_events_path: "/api/calendar_events?endeavor_id=#{item.id}"
      )
    end
  end
end
