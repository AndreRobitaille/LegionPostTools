module Api
  class CalendarController < BaseController
    include Concerns::ActivityContract

    def show
      date = params.key?(:start_date) ? activity_date(params[:start_date], field: :start_date) : Date.current
      raise ArgumentError, "start_date must be a YYYY-MM-DD date." unless date
      view = params.fetch(:view, "events")
      raise ArgumentError, "view must be events, deadlines, or public." unless CalendarMonth::VIEWS.key?(view)

      month = CalendarMonth.new(organization: organization, date: date, view: view)
      page = collection_page(month.entries)
      return unless page

      render json: {
        calendar: {
          date: month.date, view: month.view, timezone: Time.zone.name,
          entries: page[:records].map { |entry| entry_payload(entry, public_preview: month.public_preview?) }
        },
        pagination: page[:metadata]
      }
    end

    private

    def entry_payload(entry, public_preview:)
      case entry
      when CalendarEvent
        calendar_event_payload(entry, public_preview:).merge("type" => "event")
      when Meeting
        entry.attributes.slice("id", "title", "starts_at", "location_name", "location_address").merge("type" => "meeting")
      when CalendarDeadline
        { type: "deadline", title: entry.title, due_on: entry.record.due_on, endeavor_id: entry.endeavor.id,
          task_id: (entry.id if entry.record.is_a?(EndeavorTask)) }
      end
    end
  end
end
