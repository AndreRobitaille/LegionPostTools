require "test_helper"

class RosterImports::CsvParserTest < ActiveSupport::TestCase
  HEADERS = "Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status"

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
    result = RosterImports::CsvParser.new("﻿#{csv}").parse

    assert result.valid?
    assert_equal 2, result.rows.size
  end

  test "parses binary csv with utf-8 bom" do
    csv = file_fixture("roster_valid.csv").read.b
    result = RosterImports::CsvParser.new("﻿#{csv}").parse

    assert result.valid?
    assert_equal 2, result.rows.size
  end

  test "missing member id becomes a problem, not fatal; other rows still parse" do
    csv = "#{HEADERS}\n,\"No, Id\",165,Member,1 A St,,a@x.com,555,Army,Vietnam,5,2026,Active\n000204540637,\"Ok, Person\",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active\n"
    result = RosterImports::CsvParser.new(csv).parse
    assert result.valid?
    assert_equal 1, result.rows.size
    assert_equal "000204540637", result.rows.first.member_number
    assert_equal 1, result.problems.size
    assert_equal "missing_member_id", result.problems.first.kind
    assert_equal 2, result.problems.first.row
  end

  test "duplicate member id keeps the first row and problems the rest" do
    csv = "#{HEADERS}\n000204540637,\"A, One\",165,Member,1 A St,,a@x.com,555,Army,Vietnam,5,2026,Active\n000204540637,\"A, Dup\",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active\n"
    result = RosterImports::CsvParser.new(csv).parse
    assert result.valid?
    assert_equal 1, result.rows.size
    assert_equal 1, result.problems.size
    assert_equal "duplicate_member_id", result.problems.first.kind
  end

  test "missing required headers is fatal" do
    csv = "Member ID,Name\n000204540637,\"A, One\"\n"
    result = RosterImports::CsvParser.new(csv).parse
    assert_not result.valid?
    assert_equal [], result.rows
    assert_match(/Missing required columns/, result.fatal_errors.first)
  end

  test "malformed csv is fatal" do
    csv = "#{HEADERS}\n000204540637,\"Smith, John,165,Member\n"
    result = RosterImports::CsvParser.new(csv).parse
    assert_not result.valid?
    assert_not_empty result.fatal_errors
  end
end
