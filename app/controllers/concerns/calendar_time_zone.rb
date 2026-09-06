module CalendarTimeZone
  extend ActiveSupport::Concern

  included do
    around_action :in_calendar_time_zone
  end

  private

  def in_calendar_time_zone(&action)
    zone = Organization.first&.calendar_time_zone || Time.zone
    Time.use_zone(zone, &action)
  end
end
