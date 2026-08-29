module Api
  class DatedAgendasController < BaseController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_dated_agenda, only: %i[show approve publish reopen]

    def index
      render json: { dated_agendas: ordered_agendas.map { |agenda| agenda_summary(agenda) } }
    end

    def show
      render json: { dated_agenda: agenda_detail(@dated_agenda) }
    end

    def create
      meeting_body = organization.meeting_bodies.find(params[:meeting_body_id])
      meeting_type = organization.meeting_types.active.find(params[:meeting_type_id])
      starts_at = Time.zone.parse(params[:starts_at].to_s)
      raise ArgumentError, "starts_at can't be blank" if starts_at.blank?

      agenda = DatedAgenda.create_from_template!(
        organization: organization,
        meeting_body: meeting_body,
        meeting_type: meeting_type,
        starts_at: starts_at,
        title: params[:title]
      )
      render json: { dated_agenda: agenda_detail(agenda) }, status: :created
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      message = e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : e.message
      render_error(message, status: :unprocessable_entity, details: Array(e.try(:record)&.errors&.full_messages))
    end

    def approve
      @dated_agenda.approve!(current_user)
      render json: { dated_agenda: agenda_summary(@dated_agenda) }
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
      render_error(@dated_agenda.errors.full_messages.to_sentence.presence || "Could not approve this agenda.", status: :unprocessable_entity)
    end

    def publish
      @dated_agenda.publish!(current_user)
      render json: { dated_agenda: agenda_summary(@dated_agenda) }
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
      render_error(@dated_agenda.errors.full_messages.to_sentence.presence || "Could not publish this agenda.", status: :unprocessable_entity)
    end

    def reopen
      @dated_agenda.reopen!(current_user)
      render json: { dated_agenda: agenda_summary(@dated_agenda) }
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

    def agenda_summary(agenda)
      {
        id: agenda.id,
        title: agenda.title,
        status: agenda.status,
        starts_at: agenda.starts_at.iso8601,
        meeting_body: meeting_body_payload(agenda.meeting_body),
        meeting_type: meeting_type_payload(agenda.meeting_type)
      }
    end

    def agenda_detail(agenda)
      agenda_summary(agenda).merge(
        sections: agenda.dated_agenda_sections.ordered.includes(
          agenda_items: [ :rich_text_body, :rich_text_commander_notes, :roll_call_entries ]
        ).map { |section| section_payload(section) }
      )
    end

    def section_payload(section)
      {
        id: section.id,
        title: section.title,
        position: section.position,
        items: section.agenda_items.order(:position, :title).map { |item| item_payload(item) }
      }
    end

    def item_payload(item)
      {
        id: item.id,
        title: item.title,
        summary: item.summary,
        position: item.position,
        behavior_type: item.behavior_type,
        tracked_item_id: item.tracked_item_id,
        wording: item.body.to_plain_text.presence,
        show_wording_on_agenda: item.show_wording_on_agenda,
        show_wording_in_minutes: item.show_wording_in_minutes,
        commander_notes: item.commander_notes.to_plain_text.presence,
        roll_call: item.roll_call? ? item.roll_call_entries.map { |entry| roll_call_entry_payload(entry) } : nil
      }
    end

    def roll_call_entry_payload(entry)
      {
        office: entry.office_name,
        officer: entry.person_name,
        vacant: entry.vacant?
      }
    end
  end
end
