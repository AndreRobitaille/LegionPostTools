class CalendarController < ApplicationController
  before_action :require_authentication
  before_action :require_calendar_management, only: :manage

  def show
    load_month
  end

  def manage
    load_month
    render :show unless performed?
  end

  private

  def load_month
    @managing = action_name == "manage"
    date = params[:start_date].present? ? Date.iso8601(params[:start_date]) : Date.current
    raise Date::Error unless (1900..2200).cover?(date.year)

    @month = CalendarMonth.new(organization: Organization.first!, date: date, view: params[:view])
  rescue Date::Error, TypeError
    redirect_to calendar_path, alert: "Choose a valid calendar month between 1900 and 2200."
  end

  def require_calendar_management
    redirect_to root_path, alert: "You do not have permission to manage the calendar." unless current_user.can_manage_calendar?
  end
end
