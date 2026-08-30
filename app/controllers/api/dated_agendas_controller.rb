module Api
  class DatedAgendasController < BaseController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_dated_agenda, only: %i[show destroy approve publish reopen]

    def index
      render json: { dated_agendas: ordered_agendas.map { |agenda| agenda_summary_payload(agenda) } }
    end

    def show
      render json: { dated_agenda: agenda_detail_payload(@dated_agenda) }
    end

    def create
      meeting = organization.meetings.find(params[:meeting_id])
      agenda = DatedAgenda.create_from_template!(meeting: meeting)
      render json: { dated_agenda: agenda_detail_payload(agenda) }, status: :created
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      message = e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : e.message
      render_error(message, status: :unprocessable_entity, details: Array(e.try(:record)&.errors&.full_messages))
    end

    def destroy
      deleted = agenda_summary_payload(@dated_agenda)
      meeting = @dated_agenda.meeting
      @dated_agenda.destroy!
      render json: { deleted_dated_agenda: deleted, meeting: meeting_payload(meeting) }
    rescue ActiveRecord::RecordNotDestroyed => e
      render_validation_error(e.record, fallback: "Could not delete this agenda.")
    end

    def approve
      @dated_agenda.approve!(current_user)
      render json: { dated_agenda: agenda_summary_payload(@dated_agenda) }
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
      render_error(@dated_agenda.errors.full_messages.to_sentence.presence || "Could not approve this agenda.", status: :unprocessable_entity)
    end

    def publish
      @dated_agenda.publish!(current_user)
      render json: { dated_agenda: agenda_summary_payload(@dated_agenda) }
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
      render_error(@dated_agenda.errors.full_messages.to_sentence.presence || "Could not publish this agenda.", status: :unprocessable_entity)
    end

    def reopen
      @dated_agenda.reopen!(current_user)
      render json: { dated_agenda: agenda_summary_payload(@dated_agenda) }
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
      render_error(@dated_agenda.errors.full_messages.to_sentence.presence || "Could not reopen this agenda.", status: :unprocessable_entity)
    end

    private

    def set_dated_agenda
      @dated_agenda = organization.dated_agendas.find(params[:id])
    end

    def ordered_agendas
      start_of_today = Time.zone.today.beginning_of_day
      upcoming = organization.dated_agendas.where("starts_at >= ?", start_of_today).order(:starts_at, :title)
      past = organization.dated_agendas.where("starts_at < ?", start_of_today).order(starts_at: :desc, title: :asc)
      upcoming.to_a + past.to_a
    end
  end
end
