module CalendarCategories
  LABELS = { "member_meeting" => "Member Meeting", "officer_meeting" => "Officer Meeting",
    "planning_meeting" => "Planning meetings", "honor_guard" => "Honor Guard",
    "public_event" => "Public events", "other" => "Other activities", "deadline" => "Due dates" }.freeze
  EDITABLE = LABELS.except("deadline", "public_event").freeze
  LEGACY_VALUES = %w[volunteers].freeze

  def self.for(entry)
    return "deadline" if entry.is_a?(CalendarDeadline)
    override = entry.calendar_category
    return override if EDITABLE.key?(override) && override != "other"

    names = [ entry.title ]
    names += [ entry.meeting_body&.name, entry.meeting_type&.name ] if entry.is_a?(Meeting)
    text = names.compact.join(" ")
    unless override == "other"
      return "honor_guard" if text.match?(/\bhonor guard\b/i)
      return "officer_meeting" if text.match?(/\b(officers? (meeting|planning)|executive committee|executive board|PEC)\b/i)
      return "member_meeting" if text.match?(/\b(membership|members?) meeting\b/i) || (entry.is_a?(Meeting) && text.match?(/\bmembership\b/i))
      return "planning_meeting" if text.match?(/\bplanning (meeting|session)\b/i)
    end
    return "public_event" if entry.is_a?(CalendarEvent) && entry.public?

    "other"
  end
end
