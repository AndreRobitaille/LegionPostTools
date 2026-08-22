require "test_helper"

class MembershipReportTest < ActiveSupport::TestCase
  setup do
    @report = MembershipReport.new(membership_year: "2027")
  end

  test "classifies renewal states without claiming paid-ahead members are multiyear" do
    assert_equal "removed", @report.renewal_state(person("Removed", status: "Active", year: 2027, removed: true))
    assert_equal "deceased", @report.renewal_state(person("Deceased", status: "Deceased", year: 2027))
    assert_equal "lapsed", @report.renewal_state(person("Expired", status: "Expired", year: 2026))
    assert_equal "unknown", @report.renewal_state(person("Unknown", status: "Suspended", year: 2026))
    assert_equal "paid_up_for_life", @report.renewal_state(person("PUFL", status: "Active", year: 2026, type: "Paid Up For Life"))
    assert_equal "unknown", @report.renewal_state(person("Missing", status: "Grace", year: nil))
    assert_equal "paid_ahead", @report.renewal_state(person("Ahead", status: "Active", year: 2028))
    assert_equal "paid_for_year", @report.renewal_state(person("Paid", status: "Active", year: 2027))
    assert_equal "needs_renewal", @report.renewal_state(person("Due", status: "Active", year: 2026))
  end

  test "summary counts roster records current members and disjoint renewal states" do
    person("Removed", status: "Active", year: 2027, removed: true)
    person("Expired", status: "Expired", year: 2026)
    person("PUFL", status: "Active", year: 2027, type: "Paid Up For Life")
    person("Paid", status: "Grace", year: 2027)
    person("Due", status: "Active", year: 2026)

    summary = @report.summary

    assert_equal 5, summary.dig(:counts, :total_roster_records)
    assert_equal 4, summary.dig(:counts, :present_roster_records)
    assert_equal 3, summary.dig(:counts, :current_members)
    assert_equal 1, summary.dig(:counts, "removed")
    assert_equal 1, summary.dig(:counts, "lapsed")
    assert_equal 1, summary.dig(:counts, "paid_up_for_life")
    assert_equal 1, summary.dig(:counts, "paid_for_year")
    assert_equal 1, summary.dig(:counts, "needs_renewal")
  end

  test "reports the latest completed roster import and staleness" do
    RosterImport.create!(status: "completed", imported_at: 40.days.ago, uploaded_filename: "old.csv")
    newest = RosterImport.create!(status: "completed", imported_at: 2.days.ago, uploaded_filename: "new.csv")
    RosterImport.create!(status: "failed", imported_at: Time.current, uploaded_filename: "failed.csv")

    source = @report.roster_source

    assert_equal newest.imported_at.iso8601, source[:imported_at]
    assert_not source[:stale]
    assert_equal 30, source[:stale_after_days]
  end

  test "requires a supported explicit membership year" do
    assert_raises(ArgumentError, match: /four-digit year/) { MembershipReport.new(membership_year: nil) }
    assert_raises(ArgumentError, match: /between 2000 and 2100/) { MembershipReport.new(membership_year: "1999") }
  end

  private

  def person(label, status:, year:, type: "Member", removed: false)
    Person.create!(
      first_name: label,
      last_name: "Member",
      member_number: SecureRandom.random_number(10**12).to_s.rjust(12, "0"),
      roster_member_status: status,
      roster_membership_type: type,
      roster_paid_through_year: year,
      roster_removed_at: (Time.current if removed)
    )
  end
end
