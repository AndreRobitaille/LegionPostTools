# A dated projection of a project or next step, never a scheduled attendance event.
CalendarDeadline = Data.define(:record) do
  def id = record.id
  def title = "Due: #{record.title}"
  def starts_at = record.due_on.beginning_of_day
  def endeavor = record.is_a?(Endeavor) ? record : record.endeavor
end
