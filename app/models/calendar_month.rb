class CalendarMonth
  VIEWS = { "events" => "Meetings and events", "deadlines" => "Include due dates", "public" => "Public events preview" }.freeze

  attr_reader :date, :entries, :view

  def initialize(organization:, date:, view: "events")
    @date = date.beginning_of_month
    @view = VIEWS.key?(view) ? view : "events"
    from = @date.beginning_of_week.beginning_of_day
    to = (@date.end_of_month.end_of_week + 1.day).beginning_of_day
    events = organization.calendar_events.overlapping(from, to)
    if public_preview?
      records = events.publicly_visible.to_a
    else
      records = events.includes(:endeavor).to_a + organization.meetings.where(starts_at: from...to).to_a
      if @view == "deadlines"
        projects = organization.endeavors.active.where(raise_by_on: from.to_date...to.to_date)
        tasks = EndeavorTask.open.joins(:endeavor).where(endeavors: { organization_id: organization.id }).where(due_on: from.to_date...to.to_date).includes(:endeavor)
        records += (projects.to_a + tasks.to_a).map { |record| CalendarDeadline.new(record) }
      end
    end
    @entries = records.sort_by { |entry| [ entry.starts_at, entry.title.downcase, entry.id ] }
  end

  def public_preview? = view == "public"

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
