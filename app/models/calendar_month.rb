class CalendarMonth
  attr_reader :date, :entries

  def initialize(organization:, date:)
    @date = date.beginning_of_month
    from = @date.beginning_of_week.beginning_of_day
    to = (@date.end_of_month.end_of_week + 1.day).beginning_of_day
    meetings = organization.meetings.where(starts_at: from...to).to_a
    events = organization.calendar_events.overlapping(from, to).includes(:endeavor).to_a
    @entries = (meetings + events).sort_by { |entry| [ entry.starts_at, entry.title.downcase, entry.id ] }
  end

  def entries_on(day)
    entries.select do |entry|
      last_day = entry.is_a?(CalendarEvent) ? (entry.ends_at || entry.starts_at).to_date : entry.starts_at.to_date
      entry.starts_at.to_date <= day && last_day >= day
    end
  end

  def scheduled_days
    (date..date.end_of_month).filter_map do |day|
      daily_entries = entries_on(day)
      [ day, daily_entries ] if daily_entries.any?
    end
  end
end
