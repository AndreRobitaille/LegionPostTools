require "test_helper"

class RosterImports::ImporterTest < ActiveSupport::TestCase
  test "imports new people by member id and creates successful roster import" do
    result = RosterImports::Importer.new(csv_text: file_fixture("roster_valid.csv").read, filename: "roster_valid.csv").import

    assert result.success?
    assert_equal 2, result.created_count
    assert_equal 0, result.updated_count
    assert_equal 0, result.problem_count
    assert_equal 2, Person.where(member_number: %w[000204540637 000204540638]).count
    assert_equal "completed", result.roster_import.status
  end

  test "reimport updates roster fields without changing user login email" do
    person = Person.create!(first_name: "John", last_name: "Smith", member_number: "000204540637", email_address: "login@example.com")
    user = User.create!(person: person, email_address: "login@example.com")

    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Smith, John",165,Member,456 Elm St,,roster@example.com,555-2222,Navy,WWII,13,2027,Active
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "reimport.csv").import

    assert result.success?
    person.reload
    user.reload
    assert_equal "roster@example.com", person.roster_email_address
    assert_equal "login@example.com", user.email_address
    assert_equal "John", person.first_name
    assert_equal "Smith", person.last_name
  end

  test "identical reimport counts existing row as unchanged" do
    Person.create!(
      first_name: "John",
      last_name: "Smith",
      member_number: "000204540637",
      roster_name: "Smith, John",
      roster_post: 165,
      roster_membership_type: "Member",
      roster_address: "456 Elm St",
      roster_undeliverable: false,
      roster_email_address: "roster@example.com",
      roster_phone_number: "555-2222",
      roster_branch: "Navy",
      roster_war_era: "WWII",
      roster_continuous_years: 13,
      roster_paid_through_year: 2027,
      roster_member_status: "Active",
      roster_imported_at: 1.day.ago
    )

    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Smith, John",165,Member,456 Elm St,,roster@example.com,555-2222,Navy,WWII,13,2027,Active
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "unchanged.csv").import

    assert result.success?
    assert_equal 0, result.updated_count
    assert_equal 1, result.unchanged_count
  end

  test "invalid upload does not create people and creates failed roster import" do
    result = RosterImports::Importer.new(csv_text: file_fixture("roster_missing_member_id.csv").read, filename: "bad.csv").import

    assert_not result.success?
    assert_equal 0, Person.where(member_number: [ nil, "" ]).count
    assert_equal "failed", result.roster_import.status
    assert_includes result.errors, "Row 2 is missing Member ID"
  end

  test "missing required headers creates failed roster import without persisting people" do
    result = nil

    assert_no_changes -> { Person.count } do
      result = RosterImports::Importer.new(csv_text: <<~CSV, filename: "missing-header.csv").import
        Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year
        000204540637,"Smith, John",165,Member,123 Main St,Y,john.smith@example.com,555-1111,Army,Vietnam,12,2026
      CSV
    end

    assert_not result.success?
    assert_equal "failed", result.roster_import.status
    assert_equal 0, Person.where(member_number: "000204540637").count
  end

  test "shared roster emails do not prevent import" do
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540639,"Smith, Jane",165,Member,1 A St,,shared@example.com,555-3333,Air Force,Korea,10,2026,Active
      000204540640,"Jones, Bob",165,Member,2 B St,,shared@example.com,555-4444,Army,Desert Storm,8,2026,Active
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "shared_emails.csv").import

    assert result.success?
    assert_equal 2, Person.where(roster_email_address: "shared@example.com").count
  end

  test "parser failure creates failed roster import without people" do
    result = RosterImports::Importer.new(csv_text: <<~CSV, filename: "malformed.csv").import
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Smith, John,165,Member,123 Main St,Y,john.smith@example.com,555-1111,Army,Vietnam,12,2026,Active
    CSV

    assert_not result.success?
    assert_equal "failed", result.roster_import.status
    assert_equal 0, Person.where(member_number: "000204540637").count
    assert_not_empty result.errors
  end

  test "person save failures roll back earlier roster updates and do not create completed import" do
    existing_person = Person.create!(first_name: "Old", last_name: "Name", member_number: "000204540637")
    failing_person = Person.new(member_number: "000204540638")

    Person.singleton_class.alias_method :original_find_or_initialize_by, :find_or_initialize_by
    Person.define_singleton_method(:find_or_initialize_by) do |member_number:|
      member_number == "000204540637" ? existing_person : failing_person
    end

    failing_person.define_singleton_method(:save!) do
      raise ActiveRecord::RecordInvalid.new(self)
    end

    begin
      result = RosterImports::Importer.new(csv_text: <<~CSV, filename: "bad-save.csv").import
        Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
        000204540637,"Smith, John",165,Member,123 Main St,Y,john.smith@example.com,555-1111,Army,Vietnam,12,2026,Active
        000204540638,"Jones, Bob",165,Member,456 Elm St,N,bob.jones@example.com,555-2222,Navy,Korea,10,2026,Active
      CSV

      assert_not result.success?
      assert_equal "failed", result.roster_import.status
      existing_person.reload
      assert_nil existing_person.roster_address
      assert_equal 1, Person.where(member_number: "000204540637").count
      assert_equal 0, Person.where(member_number: "000204540638").count
      assert_nil RosterImport.find_by(uploaded_filename: "bad-save.csv", status: "completed")
    ensure
      Person.singleton_class.alias_method :find_or_initialize_by, :original_find_or_initialize_by
      Person.singleton_class.remove_method :original_find_or_initialize_by
    end
  end
end
