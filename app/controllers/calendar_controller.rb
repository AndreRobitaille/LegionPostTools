class CalendarController < ApplicationController
  include CalendarTimeZone
  before_action :require_authentication
  before_action :require_calendar_management, only: :manage

  def show
    load_month
  end

  def manage
    load_month
    render :show unless performed?
  end

  def print
    load_month
    return if performed?

    pdf = CalendarPdf.render(organization: @organization, month: @month)
    send_data pdf, filename: CalendarPdf.filename(month: @month), type: "application/pdf", disposition: "inline"
    no_store
  rescue CalendarPdf::GenerationError => error
    Rails.logger.error("Calendar PDF generation failed: #{error.message}")
    redirect_to calendar_path(start_date: @month.date, view: @month.view,
      categories: @month.categories.presence || [ "" ], display: params[:display]),
      alert: "The calendar PDF could not be created. Try again."
  end

  private

  def load_month
    @managing = action_name == "manage"
    @organization = Organization.first!
    date = params[:start_date].present? ? Date.iso8601(params[:start_date]) : Date.current
    raise Date::Error unless (1900..2200).cover?(date.year)

    @month = CalendarMonth.new(organization: @organization, date: date, view: params[:view], categories: params[:categories])
  rescue Date::Error, TypeError
    redirect_to calendar_path, alert: "Choose a valid calendar month between 1900 and 2200."
  end

  def require_calendar_management
    redirect_to root_path, alert: "You do not have permission to manage the calendar." unless current_user.can_manage_calendar?
  end
end
