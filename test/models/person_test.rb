require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "full_name joins first and last name" do
    person = Person.new(first_name: "Jane", last_name: "Doe")

    assert_equal "Jane Doe", person.full_name
  end

  test "roster display name uses imported roster name when present" do
    person = Person.new(first_name: "Vincent", last_name: "Alber", roster_name: "Alber, Vincent")

    assert_equal "Alber, Vincent", person.roster_display_name
  end

  test "roster display name falls back to full name" do
    person = Person.new(first_name: "Jane", last_name: "Doe")

    assert_equal "Jane Doe", person.roster_display_name
  end

  test "requires first_name and last_name" do
    person = Person.new

    assert_not person.valid?
    assert_includes person.errors[:first_name], "can't be blank"
    assert_includes person.errors[:last_name], "can't be blank"
  end

  test "blank member_number values are normalized to nil and do not violate uniqueness" do
    person_one = Person.create!(first_name: "Blank", last_name: "One", member_number: "")
    person_two = Person.create!(first_name: "Blank", last_name: "Two", member_number: "   ")

    assert_nil person_one.reload.member_number
    assert_nil person_two.reload.member_number
  end

  test "current_role_label returns the active title with the lowest display_order" do
    org = Organization.create!(name: "Post 1", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "John", last_name: "Doe")
    commander = PositionTitle.create!(organization: org, name: "Commander", display_order: 1)
    adjutant = PositionTitle.create!(organization: org, name: "Adjutant", display_order: 2)
    PositionAssignment.create!(person: person, position_title: adjutant, starts_on: Date.current)
    PositionAssignment.create!(person: person, position_title: commander, starts_on: Date.current)

    assert_equal "Commander", person.current_role_label
  end

  test "current_role_label is nil without an active assignment" do
    person = Person.create!(first_name: "Jane", last_name: "Roe")
    assert_nil person.current_role_label
  end

  test "current_role_label ignores ended assignments" do
    org = Organization.create!(name: "Post 2", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Past", last_name: "Officer")
    title = PositionTitle.create!(organization: org, name: "Historian", display_order: 5)
    PositionAssignment.create!(person: person, position_title: title,
      starts_on: Date.current - 400, ends_on: Date.current - 30)

    assert_nil person.current_role_label
  end

  test "active_role_labels lists active offices ordered by display_order then name" do
    org = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "A", last_name: "B")
    later = PositionTitle.create!(organization: org, name: "Quartermaster", display_order: 2)
    first = PositionTitle.create!(organization: org, name: "Adjutant", display_order: 1)
    ended = PositionTitle.create!(organization: org, name: "Historian", display_order: 3)
    PositionAssignment.create!(person: person, position_title: later, starts_on: Date.new(2026, 1, 1))
    PositionAssignment.create!(person: person, position_title: first, starts_on: Date.new(2026, 1, 1))
    PositionAssignment.create!(person: person, position_title: ended,
      starts_on: Date.new(2023, 1, 1), ends_on: Date.new(2024, 1, 1))

    assert_equal [ "Adjutant", "Quartermaster" ], person.active_role_labels(Date.new(2026, 6, 1))
  end

  test "service_summary joins branch and era, dropping blanks" do
    assert_equal "U.S. Army · Vietnam", Person.new(roster_branch: "U.S. Army", roster_war_era: "Vietnam").service_summary
    assert_equal "U.S. Army", Person.new(roster_branch: "U.S. Army").service_summary
    assert_equal "", Person.new.service_summary
  end

  test "roster_paid_through_display shows PUFL or the year" do
    assert_equal "Paid up for life", Person.new(roster_membership_type: "Paid Up For Life member").roster_paid_through_display
    assert_equal "Paid through: 2027", Person.new(roster_paid_through_year: 2027).roster_paid_through_display
    assert_equal "", Person.new.roster_paid_through_display
  end
end
