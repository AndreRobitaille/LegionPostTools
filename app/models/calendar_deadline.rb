# A dated projection of a project or next step, never a scheduled attendance event.
CalendarDeadline = Data.define(:record) do
  def id = record.id
  def title = "Due: #{record.title}"
  def starts_at = record.due_on.in_time_zone(endeavor.organization.calendar_time_zone)
  def endeavor = record.is_a?(Endeavor) ? record : record.endeavor
end
