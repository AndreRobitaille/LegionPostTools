class MembershipWorkspace
  class AccessDenied < StandardError; end
  class Conflict < StandardError; end

  CONFIRMED_STATES = %w[paid_up_for_life paid_ahead paid_for_year].freeze
  WORK_STATES = {
    "confirmed" => "Paid for this membership year", "post_received" => "Post received dues; confirm with National",
    "national_reported" => "Member says paid online; confirm with National", "needs_contact" => "Renewal follow-up needed",
    "held" => "Renewal contact paused", "review" => "Check the membership record",
    "no_outreach" => "No outreach: deceased or removed from the roster"
  }.freeze

  attr_reader :access, :report

  def self.default_year
    date = Organization.current_local_date
    date.month >= 7 ? date.year + 1 : date.year
  end

  def self.initial_year(user:, organization:)
    preferred = default_year
    access = MembershipAccess.new(user:, organization:)
    return preferred if access.manager?

    years = access.assignments.where(person_id: access.people.select(:id)).distinct.pluck("membership_drives.membership_year")
    years.include?(preferred) ? preferred : years.max || preferred
  end

  def initialize(user:, organization:, membership_year:)
    @report = MembershipReport.new(membership_year:)
    @access = MembershipAccess.new(user:, organization:, membership_year: @report.membership_year)
  end

  def people
    @people ||= access.people.order(:last_name, :first_name, :id).to_a
  end

  def person(id)
    access.people.find(id)
  end

  def contacts_for(person)
    access.contacts.where(person:, membership_year: report.membership_year).recent
  end

  def last_contact(person)
    @last_contacts ||= access.contacts.where(membership_year: report.membership_year).for_current_work.to_a.group_by(&:person_id).transform_values(&:first)
    @last_contacts[person.id]
  end

  def work_item(person)
    return contact_work_item(person, purpose: "renewal") if access.manager?

    @assignments_by_person ||= access.assignments.includes(:membership_drive).to_a.group_by(&:person_id)
    @assignments_by_person.fetch(person.id).map do |assignment|
      contact_work_item(person, purpose: assignment.membership_drive.purpose, assignment:)
    end.min_by { |item| [ item[:needs_attention] ? 0 : 1, item[:priority], item[:follow_up_on] || Date.new(2101) ] }
  end

  def contact_paused?(person, purpose: "renewal")
    contact_choice(person, purpose:)&.outcome == "do_not_contact"
  end

  def contact_choice(person, purpose:)
    access.organization.membership_contacts.where(person:, purpose:,
      outcome: %w[do_not_contact contact_permission_restored]).recent.first
  end

  def work_state(person)
    state = report.renewal_state(person)
    return "no_outreach" if outreach_exclusion(person)
    return "confirmed" if CONFIRMED_STATES.include?(state)
    return "held" if contact_paused?(person)

    records = effective_dues.select { |record| record.person_id == person.id }
    return "post_received" if records.any? { |record| record.kind == "post_receipt" }
    return "national_reported" if records.any? { |record| record.kind == "national_reported" }
    return "review" if state == "unknown"

    "needs_contact"
  end

  def effective_dues
    @effective_dues ||= begin
      scope = access.organization.membership_dues_records.effective.where(membership_year: report.membership_year)
      scope = scope.where(person_id: access.people.select(:id)) unless access.manager?
      scope.to_a
    end
  end

  def eligible_for_drive?(person, drive)
    return false if outreach_exclusion(person)
    return false if contact_paused?(person, purpose: drive.purpose)
    return true unless drive.purpose == "renewal"

    contact_work_item(person, purpose: "renewal")[:outreach_needed]
  end

  def outreach_exclusion(person)
    return "Deceased in National roster; no outreach" if person.normalized_roster_status == "deceased"
    "Removed from imported roster; no outreach" if person.roster_removed_at.present?
  end

  def check_contact_recording!(person, attributes)
    reason = outreach_exclusion(person)
    return unless reason
    return if access.manager? && (attributes[:channel] == "administrative_review" || attributes[:paper_reference].present?)

    raise AccessDenied, "#{reason}. An officer can still record a review or returned call sheet."
  end

  def summary
    require_manager!
    work_counts = WORK_STATES.keys.index_with(0)
    people.each { |person| work_counts[work_state(person)] += 1 }
    report.summary.merge(
      captured_at: Time.current.iso8601,
      work_counts:,
      roster_import_id: RosterImport.latest_successful&.id,
      post_dues_received: effective_dues.select { |record| record.kind == "post_receipt" }.sum(0.to_d, &:amount).to_s("F"),
      post_share_checks_received: effective_dues.select { |record| record.kind == "post_share_received" }.sum(0.to_d, &:amount).to_s("F"),
      note: "Today's roster and recorded Post work. Post-share checks do not determine individual membership. This is not an official Department count or historical retention calculation."
    )
  end

  def record_contact!(attributes)
    target = person(attributes.fetch(:person_id))
    check_contact_recording!(target, attributes)
    assignment = if attributes[:membership_assignment_id].present?
      access.assignments.find(attributes[:membership_assignment_id])
    end
    raise AccessDenied, "Choose an active assignment before recording a contact." unless access.manager? || assignment
    contact = access.organization.membership_contacts.new(attributes.slice(:channel, :outcome, :occurred_on, :notes, :follow_up_on, :paper_reference, :submission_key))
    contact.assign_attributes(person: target, recorded_by: access.user, membership_assignment: assignment,
      membership_year: report.membership_year, purpose: assignment&.membership_drive&.purpose || attributes[:purpose] || "renewal")

    require_manager! if contact.outcome == "contact_permission_restored" || contact.channel == "administrative_review"
    choice = contact_choice(target, purpose: contact.purpose)
    historical_entry = access.manager? && (contact.paper_reference.present? || (contact.occurred_on && choice && contact.occurred_on < choice.occurred_on))
    if choice&.outcome == "do_not_contact" && !%w[do_not_contact contact_permission_restored].include?(contact.outcome) &&
        contact.channel != "administrative_review" && !historical_entry
      raise AccessDenied, "Contact is paused. A membership officer must review the member's contact choice."
    end

    MembershipContact.transaction do
      contact = save_entry!(contact)
      if contact.purpose == "renewal" && contact.outcome == "already_paid_online"
        record_dues!({ person_id: target.id, kind: "national_reported", received_on: contact.occurred_on,
          notes: "Reported during outreach; verify against National.", submission_key: Digest::SHA256.hexdigest("membership-contact-#{contact.id}") }, reported_by_caller: true)
      end
      @last_contacts = nil
      @work_contacts = nil
      contact
    end
  end

  def record_dues!(attributes, reported_by_caller: false)
    require_manager! unless reported_by_caller
    record = access.organization.membership_dues_records.new(attributes.slice(:kind, :received_on, :amount, :reference, :notes, :submission_key))
    record.person = person(attributes[:person_id]) if attributes[:person_id].present?
    record.assign_attributes(recorded_by: access.user, membership_year: report.membership_year)
    save_entry!(record)
  end

  def reverse_dues!(id, notes:, submission_key:)
    require_manager!
    original = access.organization.membership_dues_records.find(id)
    previous_submission = access.organization.membership_dues_records.find_by(submission_key:)
    record = access.organization.membership_dues_records.new(
      recorded_by: access.user, person: original.person, membership_year: original.membership_year,
      kind: "reversal", reverses_record: original, amount: original.amount,
      received_on: previous_submission&.received_on || Organization.current_local_date, notes:, submission_key:
    )
    save_entry!(record)
  end

  def save_summary!(submission_key:)
    require_manager!
    existing = access.organization.membership_summaries.find_by(submission_key:)
    return matching_summary!(existing) if existing

    MembershipSummary.transaction(requires_new: true) do
      access.organization.membership_summaries.create!(created_by: access.user, membership_year: report.membership_year, payload: summary, submission_key:)
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    existing = access.organization.membership_summaries.find_by(submission_key:)
    raise unless existing

    matching_summary!(existing)
  end

  def require_manager!
    raise AccessDenied, "Membership officer access is required." unless access.manager?
  end

  def contact_work_item(person, purpose:, assignment: nil)
    item = { purpose:, assignment_id: assignment&.id, follow_up_on: nil, needs_attention: false, outreach_needed: false, priority: 4 }
    reason = outreach_exclusion(person)
    return item.merge(next_step: reason) if reason

    @work_contacts ||= access.contacts.where(membership_year: report.membership_year).for_current_work.to_a.group_by(&:person_id)
    contact = Array(@work_contacts[person.id]).find do |entry|
      entry.purpose == purpose && (assignment.nil? || entry.membership_assignment_id == assignment.id)
    end
    return item.merge(next_step: "Contact paused for this purpose") if contact_paused?(person, purpose:)

    if purpose == "renewal"
      state = work_state(person)
      case state
      when "confirmed" then return item.merge(next_step: "No renewal follow-up needed")
      when "post_received", "national_reported"
        step = state == "post_received" ? "Confirm dues received here with National" : "Verify the member's online renewal"
        return item.merge(next_step: step, needs_attention: access.manager?, priority: 2)
      when "review"
        return item.merge(next_step: "Check the membership record", needs_attention: true, priority: 1)
      end
    end

    item[:follow_up_on] = contact&.follow_up_on
    if item[:follow_up_on]
      due = item[:follow_up_on] <= Organization.current_local_date
      return item.merge(next_step: due ? "Make the agreed callback" : "Callback scheduled", needs_attention: due, outreach_needed: due, priority: due ? 0 : 4)
    end

    step = case contact&.outcome
    when "no_answer" then "Try contacting again"
    when "message_left" then "Follow up on the message"
    when "officer_review" then access.manager? ? "Review the caller's notes" : "Ask a membership officer to review"
    when "declined_renewal" then "Renewal declined"
    when "reached" then purpose == "renewal" ? "Agree on the renewal next step" : "Contact completed"
    else
      { "renewal" => "Contact about renewal", "welcome" => "Make a welcome call", "buddy_check" => "Make a Buddy Check" }.fetch(purpose)
    end
    complete = contact&.outcome == "declined_renewal" || (purpose != "renewal" && contact&.outcome == "reached")
    item.merge(next_step: step, needs_attention: !complete, outreach_needed: !complete && contact&.outcome != "officer_review", priority: complete ? 4 : 3)
  end

  private

  def save_entry!(record)
    existing = record.class.find_by(submission_key: record.submission_key)
    return matching_entry!(existing, record) if existing

    record.class.transaction(requires_new: true) { record.save! }
    record
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    existing = record.class.find_by(submission_key: record.submission_key)
    raise unless existing

    matching_entry!(existing, record)
  end

  def matching_summary!(existing)
    unless existing.created_by_id == access.user.id && existing.membership_year == report.membership_year
      raise Conflict, "This form was already used for a different summary."
    end
    existing
  end

  def matching_entry!(existing, record)
    expected = record.attributes.except("id", "created_at", "updated_at")
    unless expected.all? { |key, value| existing.public_send(key) == value }
      raise Conflict, "This form was already used for another entry. Open a new form."
    end
    existing
  end
end
