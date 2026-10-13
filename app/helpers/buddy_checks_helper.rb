module BuddyChecksHelper
  ELIGIBILITY_REASONS = {
    "contact_paused" => "Buddy Check contact is paused. Ask a Buddy Check coordinator before making another contact.",
    "assigned_elsewhere" => "Another caller is assigned to this member. Coordinate with a Buddy Check coordinator first.",
    "open_follow_up" => "A callback is already arranged. Use your callbacks or coordinate with a Buddy Check coordinator.",
    "recent_attempt" => "A recent contact attempt is recorded. Allow time before another Buddy Check.",
    "recent_conversation" => "A recent conversation is recorded. Allow time before another Buddy Check."
  }.freeze

  def buddy_eligibility_message(eligibility)
    eligibility[:eligible] ? "Available for a Buddy Check." : ELIGIBILITY_REASONS.fetch(eligibility[:reason], "Contact is unavailable. Review the current work before proceeding.")
  end

  def buddy_time(value)
    legion_datetime(value.in_time_zone(@organization.calendar_time_zone))
  end

  def buddy_contact_choices(kind, contact)
    labels = kind == :channel ? MembershipContact::CHANNELS : MembershipContact::OUTCOMES
    values = kind == :channel ? BuddyChecks::Operations::CHANNELS : BuddyChecks::Operations::OUTCOMES
    original = contact&.public_send(kind)
    values = [ original ] + values if original && !values.include?(original)
    values.map { |key| [ labels.fetch(key), key ] }
  end
end
