class MembershipReport
  VALID_YEARS = (2000..2100).freeze
  RENEWAL_STATES = %w[
    removed
    deceased
    lapsed
    unknown
    paid_up_for_life
    paid_ahead
    paid_for_year
    needs_renewal
  ].freeze
  OUTREACH_STATES = %w[needs_renewal lapsed unknown].freeze
  CURRENT_STATUSES = %w[active grace].freeze
  ROSTER_STALE_AFTER = 30.days

  attr_reader :membership_year

  def initialize(membership_year:)
    @membership_year = parse_membership_year(membership_year)
  end

  def people
    @people ||= Person.roster_backed.includes(position_assignments: :position_title).order(:last_name, :first_name, :id).to_a
  end

  def summary
    state_counts = RENEWAL_STATES.index_with(0)
    people.each { |person| state_counts[renewal_state(person)] += 1 }

    {
      membership_year: membership_year,
      counts: {
        total_roster_records: people.size,
        present_roster_records: people.count { |person| person.roster_removed_at.blank? },
        current_members: people.count { |person| person.roster_removed_at.blank? && CURRENT_STATUSES.include?(person.normalized_roster_status) }
      }.merge(state_counts),
      definitions: {
        current_members: "Present roster records with status active or grace.",
        needs_renewal: "Present active or grace members who are not PUFL and are paid through an earlier year.",
        paid_ahead: "Present active or grace members paid through a year later than the requested membership year."
      },
      roster_source: roster_source
    }
  end

  def renewal_state(person)
    return "removed" if person.roster_removed_at.present?

    case person.normalized_roster_status
    when "deceased" then return "deceased"
    when "expired" then return "lapsed"
    end

    return "unknown" unless CURRENT_STATUSES.include?(person.normalized_roster_status)
    return "paid_up_for_life" if person.paid_up_for_life?
    return "unknown" if person.roster_paid_through_year.blank?
    return "paid_ahead" if person.roster_paid_through_year > membership_year
    return "paid_for_year" if person.roster_paid_through_year == membership_year

    "needs_renewal"
  end

  def roster_source
    imported_at = RosterImport.where(status: "completed").maximum(:imported_at)
    {
      imported_at: imported_at&.iso8601,
      stale: imported_at.blank? || imported_at < ROSTER_STALE_AFTER.ago,
      stale_after_days: 30
    }
  end

  private

  def parse_membership_year(value)
    year = Integer(value.to_s, 10, exception: false)
    raise ArgumentError, "membership_year must be a four-digit year." unless year
    return year if VALID_YEARS.cover?(year)

    raise ArgumentError, "membership_year must be between #{VALID_YEARS.begin} and #{VALID_YEARS.end}."
  end
end
