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

  test "row with missing member id is a problem but does not fail the whole import" do
    result = RosterImports::Importer.new(csv_text: file_fixture("roster_missing_member_id.csv").read, filename: "bad.csv").import

    assert result.success?
    assert_equal "completed", result.roster_import.status
    assert_equal 0, Person.where(member_number: [ nil, "" ]).count
    assert result.problem_count >= 1
  end

  test "row with missing member id is a problem but valid rows still import" do
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      ,"No, Id",165,Member,1 A St,,a@x.com,555,Army,Vietnam,5,2026,Active
      000204540637,"Ok, Person",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active
    CSV
    result = RosterImports::Importer.new(csv_text: csv, filename: "partial.csv").import
    assert result.success?
    assert_equal "completed", result.roster_import.status
    assert_equal 1, result.created_count
    assert_equal 1, result.problem_count
    assert_equal 1, Person.where(member_number: "000204540637").count
    assert_equal 1, result.roster_import.summary["problems"].size
  end

  test "member absent from a new import is marked removed and their sign-in disabled" do
    gone = Person.create!(first_name: "Gone", last_name: "Member", member_number: "000000000001", roster_imported_at: 10.days.ago)
    gone_user = User.create!(person: gone, email_address: "gone@x.com", email_verified_at: Time.current)
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Ok, Person",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active
    CSV
    result = RosterImports::Importer.new(csv_text: csv, filename: "removal.csv").import
    assert result.success?
    assert_equal 1, result.removed_count
    gone.reload; gone_user.reload
    assert gone.roster_removed_at.present?
    assert gone_user.disabled_at.present?
    assert_equal "000000000001", result.roster_import.summary["removed_members"].first["member_number"]
  end

  test "the last enabled administrator is not disabled on removal; a problem is recorded" do
    admin_person = Person.create!(first_name: "Sole", last_name: "Admin", member_number: "000000000009", roster_imported_at: 10.days.ago)
    admin_user = User.create!(person: admin_person, email_address: "admin@x.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: admin_user, capability: "manage_settings")
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Ok, Person",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active
    CSV
    result = RosterImports::Importer.new(csv_text: csv, filename: "last-admin.csv").import
    admin_user.reload
    assert_nil admin_user.disabled_at
    assert(result.roster_import.summary["problems"].any? { |p| p["kind"] == "last_admin" })
  end

  test "returning member clears roster_removed_at but does not re-enable sign-in" do
    back = Person.create!(first_name: "Back", last_name: "Again", member_number: "000204540637",
      roster_imported_at: 20.days.ago, roster_removed_at: 5.days.ago)
    back_user = User.create!(person: back, email_address: "back@x.com", email_verified_at: Time.current, disabled_at: 5.days.ago)
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Back, Again",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active
    CSV
    RosterImports::Importer.new(csv_text: csv, filename: "return.csv").import
    back.reload; back_user.reload
    assert_nil back.roster_removed_at
    assert back_user.disabled_at.present?, "sign-in stays off until an officer re-enables it"
  end

  test "a file with zero valid rows never mass-removes" do
    keep = Person.create!(first_name: "Keep", last_name: "Me", member_number: "000000000002", roster_imported_at: 10.days.ago)
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      ,"No, Id",165,Member,1 A St,,a@x.com,555,Army,Vietnam,5,2026,Active
    CSV
    result = RosterImports::Importer.new(csv_text: csv, filename: "all-problems.csv").import
    assert_equal 0, result.removed_count
    keep.reload
    assert_nil keep.roster_removed_at
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
