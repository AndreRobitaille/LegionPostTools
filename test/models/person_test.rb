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

  test "first last display puts generational suffixes after the surname without changing saved fields" do
    [
      [ "Charles", "Example Sr.", "Charles Example, Sr." ],
      [ "Charles Sr.", "Example", "Charles Example, Sr." ],
      [ "Charles, Sr.", "Example", "Charles Example, Sr." ],
      [ "Sr. Charles", "Example", "Charles Example, Sr." ],
      [ "Sr., Charles", "Example", "Charles Example, Sr." ],
      [ "Charles", "Sr. Example", "Charles Example, Sr." ],
      [ "Jr Don", "Example", "Don Example, Jr" ],
      [ "Don Jr", "Example", "Don Example, Jr" ],
      [ "Don", "Example, Jr.", "Don Example, Jr." ],
      [ "Alex Q. III", "de la Example", "Alex Q. de la Example III" ],
      [ "Alex-Casey IV", "O'Example-Smith", "Alex-Casey O'Example-Smith IV" ],
      [ "Charles SR", "Example Sr.", "Charles Example, SR" ],
      [ "  Don Q., jr.  ", " Example ", "Don Q. Example, jr." ]
    ].each do |first, last, expected|
      person = Person.new(first_name: first, last_name: last)
      assert_equal expected, person.first_last_display_name
      assert_equal first, person.first_name
      assert_equal last, person.last_name
    end
    %w[Sr Sr. SR sr. Jr Jr. JR jr.].each do |suffix|
      assert_equal "Alex Example, #{suffix}", Person.new(first_name: "Alex #{suffix}", last_name: "Example").first_last_display_name
    end
    %w[II III IV].each do |suffix|
      assert_equal "Alex Example #{suffix}", Person.new(first_name: "Alex #{suffix}", last_name: "Example").first_last_display_name
    end
  end

  test "first last display preserves ordinary initials names and partial names" do
    [
      [ "John V", "Example", "John V Example" ],
      [ "John I.", "Example", "John I. Example" ],
      [ "Jrue", "Example", "Jrue Example" ],
      [ "Srikanth", "Example", "Srikanth Example" ],
      [ "Alex", "Srinivasan", "Alex Srinivasan" ],
      [ "Alex Jr. Q.", "Example", "Alex Jr. Q. Example" ],
      [ "Cher", nil, "Cher" ],
      [ nil, "Example", "Example" ],
      [ nil, nil, "" ]
    ].each do |first, last, expected|
      assert_equal expected, Person.new(first_name: first, last_name: last).first_last_display_name
    end
  end

  test "first last display preserves the current roster name even when split fields are older" do
    [
      [ "Example, Charles Sr.", "Charles Example, Sr." ],
      [ "Example, Sr. Charles", "Charles Example, Sr." ],
      [ "Example, Jr. Don", "Don Example, Jr." ],
      [ "Example Jr., Don", "Don Example, Jr." ],
      [ "Example, Don, Jr.", "Don Example, Jr." ],
      [ "Charles Example, Sr.", "Charles Example, Sr." ],
      [ "Charles Example Sr.", "Charles Example, Sr." ],
      [ "Alex Example, III", "Alex Example III" ],
      [ "Alex Example", "Alex Example" ]
    ].each do |roster, expected|
      person = Person.new(first_name: "Older", last_name: "Fields", roster_name: roster)
      assert_equal expected, person.first_last_display_name
      assert_equal [ "Older", "Fields", roster ], [ person.first_name, person.last_name, person.roster_name ]
    end
  end

  test "roster display name falls back to full name" do
    person = Person.new(first_name: "Jane", last_name: "Doe")

    assert_equal "Jane Doe", person.roster_display_name
  end

  test "directory contact prefers local fields and falls back to roster fields" do
    local = Person.new(
      first_name: "Local", last_name: "Contact",
      email_address: "local@example.com", phone_number: "555-1000",
      roster_email_address: "roster@example.com", roster_phone_number: "555-2000"
    )
    roster = Person.new(
      first_name: "Roster", last_name: "Contact",
      roster_email_address: "roster@example.com", roster_phone_number: "555-2000"
    )

    assert_equal "local@example.com", local.directory_email_address
    assert_equal "555-1000", local.directory_phone_number
    assert_equal "roster@example.com", roster.directory_email_address
    assert_equal "555-2000", roster.directory_phone_number
  end

  test "directory visibility excludes removed expired and deceased people but keeps local people" do
    visible = Person.create!(first_name: "Active", last_name: "Member", roster_member_status: " Active ")
    local = Person.create!(first_name: "Local", last_name: "Officer")
    Person.create!(first_name: "Expired", last_name: "Member", roster_member_status: "EXPIRED")
    Person.create!(first_name: "Deceased", last_name: "Member", roster_member_status: "deceased")
    Person.create!(first_name: "Removed", last_name: "Member", roster_member_status: "Active", roster_removed_at: Time.current)

    assert_equal [ visible.id, local.id ].sort, Person.directory_visible.ids.sort
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
    PositionAssignment.create!(person: person, position_title: adjutant, starts_on: Organization.current_local_date)
    PositionAssignment.create!(person: person, position_title: commander, starts_on: Organization.current_local_date)

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
      starts_on: Organization.current_local_date - 400, ends_on: Organization.current_local_date - 30)

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

  test "service_summary translates roster codes and suppresses missing sentinels" do
    assert_equal "Army · Persian Gulf", Person.new(roster_branch: "USA", roster_war_era: "PERSIAN_GULF").service_summary
    assert_equal "Navy · Global War on Terrorism", Person.new(roster_branch: "USN", roster_war_era: "GW_TERRORISM").service_summary
    assert_equal "Air Force", Person.new(roster_branch: "USAF", roster_war_era: "MISSING").service_summary
  end

  test "roster_paid_through_display shows PUFL or the year" do
    assert_equal "Paid up for life", Person.new(roster_membership_type: "Paid Up For Life member").roster_paid_through_display
    assert_equal "Paid through: 2027", Person.new(roster_paid_through_year: 2027).roster_paid_through_display
    assert_equal "", Person.new.roster_paid_through_display
  end

  test "initials take the first letter of the first two names, uppercased" do
    assert_equal "AR", Person.new(first_name: "Andre", last_name: "Robitaille").initials
    assert_equal "AR", Person.new(first_name: "andre", last_name: "robitaille").initials
  end

  test "initials cope with middle names and a missing surname" do
    assert_equal "JQ", Person.new(first_name: "John Quincy", last_name: "Adams").initials
    assert_equal "C", Person.new(first_name: "Cher", last_name: "").initials
  end
end
