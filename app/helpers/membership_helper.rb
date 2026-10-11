module MembershipHelper
  RENEWAL_LABELS = {
    "removed" => "Removed from imported roster", "deceased" => "Deceased in National roster",
    "lapsed" => "Expired in National roster", "unknown" => "Standing needs review",
    "paid_up_for_life" => "Paid Up For Life", "paid_ahead" => "Paid ahead",
    "paid_for_year" => "Paid for this year", "needs_renewal" => "Not yet paid for this year"
  }.freeze

  def membership_renewal_label(person, report)
    RENEWAL_LABELS.fetch(report.renewal_state(person))
  end

  def membership_contact_options(purpose: "renewal", manager: false)
    options = MembershipContact::OUTCOMES.dup
    options.delete("contact_permission_restored") unless manager
    options.except!("already_paid_online", "wants_to_renew", "declined_renewal") if purpose == "buddy_check"
    options.map { |value, label| [ label, value ] }
  end

  def membership_channel_options(manager:)
    channels = MembershipContact::CHANNELS
    channels = channels.except("administrative_review") unless manager
    channels.map { |value, label| [ label, value ] }
  end

  def membership_assignment_label(assignment)
    label = "#{assignment.membership_drive.title} · #{assignment.assigned_to.person.full_name}"
    label += " · Revoked (returned sheet only)" if assignment.revoked_at
    label
  end

  def membership_source_date(source)
    date = source["imported_at"] || source[:imported_at]
    date ? legion_date(membership_local_time(Time.iso8601(date))) : "No completed roster import"
  end

  def membership_local_time(value)
    value.in_time_zone(@organization.calendar_time_zone)
  end
end
