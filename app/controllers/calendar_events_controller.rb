class CalendarEventsController < ApplicationController
  before_action :require_authentication
  before_action :require_calendar_management, except: :show
  before_action :set_organization
  before_action :set_event, only: %i[show edit update]
  before_action :set_endeavors, only: %i[new create edit update]

  def show
    @public_preview = params[:preview] == "public"
    raise ActiveRecord::RecordNotFound if @public_preview && !@event.public?
  end

  def new
    @event = @organization.calendar_events.new
    @event.endeavor = @organization.endeavors.find(params[:endeavor_id]) if params[:endeavor_id].present?
  end

  def create
    @event = @organization.calendar_events.new(event_params)
    @event.created_by = current_user
    @event.updated_by = current_user
    save_event(:new, "Event added to the calendar.")
  end

  def edit; end

  def update
    @event.assign_attributes(event_params)
    @event.updated_by = current_user
    save_event(:edit, "Calendar event saved.")
  rescue ActiveRecord::StaleObjectError
    redirect_to edit_calendar_event_path(@event), alert: "This event changed elsewhere. Review the latest details before saving again."
  end

  private

  def require_calendar_management
    redirect_to root_path, alert: "You do not have permission to manage the calendar." unless current_user.can_manage_calendar?
  end

  def set_organization
    @organization = Organization.first!
  end

  def set_event
    @event = @organization.calendar_events.find(params[:id])
  end

  def set_endeavors
    @endeavors = @organization.endeavors.order(:title)
  end

  def event_params
    params.require(:calendar_event).permit(:title, :description, :location, :endeavor_id, :visibility, :all_day, :cancelled, :lock_version)
  end

  def save_event(template, notice)
    assign_schedule
    valid = @event.valid?
    @schedule_errors.each { |attribute, message| @event.errors.add(attribute, message) }
    if valid && @schedule_errors.empty? && @event.save
      redirect_to calendar_event_path(@event), notice: notice
    else
      render template, status: :unprocessable_entity
    end
  end

  def assign_schedule
    @schedule_errors = []
    %i[starts_at ends_at].each do |attribute|
      date_text = params[:calendar_event]["#{attribute}_date"]
      time_text = params[:calendar_event]["#{attribute}_time"]
      if attribute == :ends_at && date_text.blank? && time_text.blank?
        @event.ends_at = nil
        next
      end
      date = helpers.parse_legion_date(date_text)
      value = if @event.all_day? && date
        attribute == :ends_at ? date.end_of_day : date.beginning_of_day
      else
        helpers.combine_legion_datetime(date_text, time_text)
      end
      @schedule_errors << [ attribute, "needs a valid date#{' and 24-hour time' unless @event.all_day?}" ] unless value
      @event.public_send("#{attribute}=", value)
    end
  end
end
