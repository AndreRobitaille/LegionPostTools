class CalendarMonth
  VIEWS = { "events" => "Meetings and events", "deadlines" => "Include due dates", "public" => "Public events preview" }.freeze

  attr_reader :date, :entries, :view, :categories, :time_zone

  def initialize(organization:, date:, view: "events", categories: nil)
    @time_zone = organization.calendar_time_zone
    @date = date.beginning_of_month
    @view = VIEWS.key?(view) ? view : "events"
    @categories = categories.nil? ? CalendarCategories::LABELS.keys : Array(categories) & CalendarCategories::LABELS.keys
    from = @date.beginning_of_week(:sunday).in_time_zone(time_zone)
    to = (@date.end_of_month.end_of_week(:sunday) + 1.day).in_time_zone(time_zone)
    events = organization.calendar_events.overlapping(from, to)
    if public_preview?
      records = events.publicly_visible.to_a
    else
      records = events.includes(:endeavor).to_a + organization.meetings.includes(:meeting_body, :meeting_type).where(starts_at: from...to).to_a
      if @view == "deadlines"
        projects = organization.endeavors.active.where(raise_by_on: from.to_date...to.to_date)
        tasks = EndeavorTask.open.joins(:endeavor).where(endeavors: { organization_id: organization.id }).where(due_on: from.to_date...to.to_date).includes(:endeavor)
        records += (projects.to_a + tasks.to_a).map { |record| CalendarDeadline.new(record) }
      end
    end
    @all_entries = records.sort_by { |entry| [ entry.starts_at, entry.title.downcase, entry.id ] }
    @entries = @all_entries.select { |entry| @categories.include?(CalendarCategories.for(entry)) }
  end

  def public_preview? = view == "public"

  def entries_on(day, filtered: true)
    (filtered ? entries : @all_entries).select do |entry|
      first_day = entry.starts_at.in_time_zone(time_zone).to_date
      last_day = entry.is_a?(CalendarEvent) && entry.ends_at ? entry.ends_at.in_time_zone(time_zone).to_date : first_day
      first_day <= day && last_day >= day
    end
  end

  def scheduled_days(filtered: true)
    (date..date.end_of_month).filter_map do |day|
      daily_entries = entries_on(day, filtered: filtered)
      [ day, daily_entries ] if daily_entries.any?
    end
  end
end
