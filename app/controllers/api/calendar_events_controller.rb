module Api
  class CalendarEventsController < BaseController
    include CalendarTimeZone
    include Concerns::ActivityContract
    before_action :require_calendar_management, only: %i[create update]
    before_action :set_event, only: %i[show update]

    def index
      preview = activity_preview?
      if preview && (params[:endeavor_id].present? || params[:visibility] == "members")
        raise ArgumentError, "Public preview cannot filter by private Endeavor links or member visibility."
      end
      scope = organization.calendar_events.order(:starts_at, :id)
      scope = scope.where(endeavor: organization.endeavors.find(params[:endeavor_id])) if params[:endeavor_id].present?
      if params.key?(:visibility)
        raise ArgumentError, "visibility must be members or public." unless CalendarEvent::VISIBILITIES.key?(params[:visibility])
        scope = scope.where(visibility: params[:visibility])
      end
      scope = scope.publicly_visible if preview
      page = collection_page(scope)
      return unless page

      render json: { calendar_events: page[:records].map { |event| calendar_event_payload(event, public_preview: preview) }, pagination: page[:metadata], timezone: Time.zone.name }
    end

    def show
      preview = activity_preview?
      raise ActiveRecord::RecordNotFound if preview && !@event.public?

      render json: { calendar_event: calendar_event_payload(@event, public_preview: preview), timezone: Time.zone.name }
    end

    def create
      @event = organization.calendar_events.new(created_by: current_user, updated_by: current_user)
      assign_event_attributes
      @event.save!
      render json: { calendar_event: calendar_event_payload(@event), timezone: Time.zone.name }, status: :created
    end

    def update
      @event.lock_version = activity_lock_version!(@event)
      assign_event_attributes
      @event.updated_by = current_user
      @event.save!
      render json: { calendar_event: calendar_event_payload(@event), timezone: Time.zone.name }
    end

    private

    def require_calendar_management
      render_error("You do not have permission to manage the calendar.", status: :forbidden) unless current_user.can_manage_calendar?
    end

    def set_event
      @event = organization.calendar_events.find(params[:id])
    end

    def assign_event_attributes
      @event.assign_attributes(params.permit(:calendar_category, :title, :description, :location, :visibility))
      if params.key?(:endeavor_id)
        @event.endeavor = params[:endeavor_id].present? ? organization.endeavors.find(params[:endeavor_id]) : nil
      end
      %i[all_day cancelled].each { |field| @event.public_send("#{field}=", activity_boolean(field)) if params.key?(field) }
      if @event.persisted? && @event.all_day_changed? && !%i[starts_at ends_at].all? { |field| params.key?(field) }
        raise ArgumentError, "Changing all_day requires starts_at and ends_at (end may be null)."
      end
      %i[starts_at ends_at].each do |field|
        @event.public_send("#{field}=", event_time(params[field], field: field)) if params.key?(field)
      end
    end

    def event_time(value, field:)
      return nil if value.nil? || value == ""
      if @event.all_day?
        date = activity_date(value, field: field)
        return field == :ends_at ? date.end_of_day : date.beginning_of_day
      end
      unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})\z/)
        raise ArgumentError, "#{field} must be an ISO 8601 datetime with an explicit offset."
      end
      DateTime.iso8601(value).to_time.in_time_zone
    rescue ArgumentError
      raise ArgumentError, "#{field} must be a valid #{@event.all_day? ? 'YYYY-MM-DD date' : 'ISO 8601 datetime with an explicit offset'}."
    end
  end
end
