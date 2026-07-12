require "test_helper"

class RosterImports::CsvParserTest < ActiveSupport::TestCase
  test "parses valid fixture" do
    result = RosterImports::CsvParser.new(file_fixture("roster_valid.csv").read).parse

    assert result.valid?
    assert_equal 2, result.rows.size
    row = result.rows.first
    assert_equal "000204540637", row.member_number
    assert_equal "Smith, John", row.name
    assert_equal "165", row.post
    assert_equal "Member", row.membership_type
    assert_equal "123 Main St", row.address
    assert_equal true, row.undeliverable
    assert_equal "john.smith@example.com", row.email_address
    assert_equal "555-1111", row.phone_number
    assert_equal "Army", row.branch
    assert_equal "Vietnam", row.war_era
    assert_equal 12, row.continuous_years
    assert_equal 2026, row.paid_through_year
    assert_equal "Active", row.member_status
  end

  test "parses valid csv with utf-8 bom" do
    csv = file_fixture("roster_valid.csv").read
    result = RosterImports::CsvParser.new("\uFEFF#{csv}").parse

    assert result.valid?
    assert_equal 2, result.rows.size
  end

  test "parses binary csv with utf-8 bom" do
    csv = file_fixture("roster_valid.csv").read.b
    result = RosterImports::CsvParser.new("\uFEFF#{csv}").parse

    assert result.valid?
    assert_equal 2, result.rows.size
  end

  test "rejects duplicate member id" do
    result = RosterImports::CsvParser.new(file_fixture("roster_duplicate_member_id.csv").read).parse

    assert_not result.valid?
    assert_includes result.errors, "Duplicate Member ID 000204540637 in uploaded roster"
  end

  test "rejects missing member id" do
    result = RosterImports::CsvParser.new(file_fixture("roster_missing_member_id.csv").read).parse

    assert_not result.valid?
    assert_includes result.errors, "Row 2 is missing Member ID"
  end

  test "rejects missing required headers as invalid parser result" do
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year
      000204540637,"Smith, John",165,Member,123 Main St,Y,john.smith@example.com,555-1111,Army,Vietnam,12,2026
    CSV

    result = RosterImports::CsvParser.new(csv).parse

    assert_not result.valid?
    assert_includes result.errors, "Missing required columns: Member Status"
  end

  test "rejects malformed csv as invalid parser result" do
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Smith, John,165,Member,123 Main St,Y,john.smith@example.com,555-1111,Army,Vietnam,12,2026,Active
    CSV

    result = RosterImports::CsvParser.new(csv).parse

    assert_not result.valid?
    assert_not_empty result.errors
  end
end
