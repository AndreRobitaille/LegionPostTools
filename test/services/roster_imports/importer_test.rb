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

  test "removed already-disabled member is not marked as newly disabled in removed_members" do
    gone = Person.create!(first_name: "Gone", last_name: "Member", member_number: "000000000010", roster_imported_at: 10.days.ago)
    gone_user = User.create!(person: gone, email_address: "gone-disabled@x.com", disabled_at: 1.day.ago)
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Ok, Person",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "removal-disabled.csv").import

    assert result.success?
    assert gone_user.reload.disabled_at.present?
    assert_equal false, result.roster_import.summary["removed_members"].first["user_disabled"]
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
    assert_equal false, result.roster_import.summary["removed_members"].first["user_disabled"]
    assert admin_person.reload.roster_removed_at.present?
    assert(result.roster_import.summary["problems"].any? { |p| p["kind"] == "last_admin" })
  end

  test "unsupported roster status for a person with a user records a problem and leaves sign-in unchanged" do
    person = Person.create!(first_name: "Unknown", last_name: "Member", member_number: "000204540646", roster_imported_at: 1.day.ago)
    user = User.create!(person: person, email_address: "unknown@example.com")
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540646,"Member, Unknown",165,Member,1 A St,,unknown@example.com,555,Army,Vietnam,5,2026,Suspended
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "unsupported-status.csv").import

    assert result.success?
    assert_equal 1, result.roster_import.summary["access_effects"]["unsupported_status"]
    assert_equal "unsupported_member_status", result.roster_import.summary["problems"].first["kind"]
    assert_nil user.reload.disabled_at
  end

  test "last enabled administrator present in the CSV with expired status is not disabled and records a skipped last admin problem" do
    person = Person.create!(first_name: "Sole", last_name: "Admin", member_number: "000204540647", roster_imported_at: 1.day.ago)
    admin_user = User.create!(person: person, email_address: "sole-admin@example.com")
    PermissionGrant.create!(user: admin_user, capability: "manage_settings")
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540647,"Admin, Sole",165,Member,1 A St,,sole-admin@example.com,555,Army,Vietnam,5,2026,Expired
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "last-admin-row.csv").import

    assert result.success?
    assert_equal 1, result.roster_import.summary["access_effects"]["skipped_last_admin"]
    assert_equal "last_admin", result.roster_import.summary["problems"].first["kind"]
    assert_nil admin_user.reload.disabled_at
  end

  test "active and grace roster statuses re-enable roster-controlled existing accounts" do
    active = Person.create!(first_name: "Active", last_name: "Member", member_number: "000204540640", roster_imported_at: 1.day.ago)
    grace = Person.create!(first_name: "Grace", last_name: "Member", member_number: "000204540641", roster_imported_at: 1.day.ago)
    active_user = User.create!(person: active, email_address: "active@example.com", disabled_at: 1.day.ago)
    grace_user = User.create!(person: grace, email_address: "grace@example.com", disabled_at: 1.day.ago)
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540640,"Member, Active",165,Member,1 A St,,active@example.com,555,Army,Vietnam,5,2026,Active
      000204540641,"Member, Grace",165,Member,2 A St,,grace@example.com,555,Army,Vietnam,5,2026,Grace
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "statuses.csv").import

    assert result.success?
    assert_nil active_user.reload.disabled_at
    assert_nil grace_user.reload.disabled_at
    assert_equal 2, result.roster_import.access_effects["enabled_by_roster_status"]
  end

  test "expired and deceased roster statuses disable roster-controlled existing accounts" do
    expired = Person.create!(first_name: "Expired", last_name: "Member", member_number: "000204540642", roster_imported_at: 1.day.ago)
    deceased = Person.create!(first_name: "Deceased", last_name: "Member", member_number: "000204540643", roster_imported_at: 1.day.ago)
    expired_user = User.create!(person: expired, email_address: "expired-status@example.com")
    deceased_user = User.create!(person: deceased, email_address: "deceased-status@example.com")
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540642,"Member, Expired",165,Member,1 A St,,expired@example.com,555,Army,Vietnam,5,2026,Expired
      000204540643,"Member, Deceased",165,Member,2 A St,,deceased@example.com,555,Army,Vietnam,5,2026,Deceased
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "statuses.csv").import

    assert result.success?
    assert expired_user.reload.disabled_at.present?
    assert deceased_user.reload.disabled_at.present?
    assert_equal 2, result.roster_import.access_effects["disabled_by_roster_status"]
  end

  test "imports skip admin override accounts" do
    person = Person.create!(first_name: "Override", last_name: "Member", member_number: "000204540644", roster_imported_at: 1.day.ago)
    user = User.create!(person: person, email_address: "override-import@example.com", login_access_override: true, login_access_override_at: Time.current)
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540644,"Member, Override",165,Member,1 A St,,override@example.com,555,Army,Vietnam,5,2026,Expired
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "override.csv").import

    assert result.success?
    assert_nil user.reload.disabled_at
    assert_equal 1, result.roster_import.access_effects["skipped_admin_override"]
  end

  test "imports do not create login accounts" do
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540645,"Member, New",165,Member,1 A St,,new@example.com,555,Army,Vietnam,5,2026,Active
    CSV

    assert_no_difference -> { User.count } do
      RosterImports::Importer.new(csv_text: csv, filename: "new.csv").import
    end
  end

  test "returning active member clears roster_removed_at and re-enables roster-controlled sign-in" do
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
    assert_nil back_user.disabled_at
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

  test "more than ten removals creates pending confirmation without mutating people or users" do
    people = []
    users = []
    11.times do |index|
      person = Person.create!(first_name: "Gone", last_name: index.to_s, member_number: format("G%03d", index), roster_imported_at: 1.day.ago)
      people << person
      users << User.create!(person: person, email_address: "gone#{index}@example.com")
    end
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Still, Here",165,Member,1 A St,,still@example.com,555,Army,Vietnam,5,2026,Active
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "large-removal.csv").import

    assert_not result.success?
    assert_equal "pending_confirmation", result.roster_import.status
    assert_equal 11, result.roster_import.removed_count
    assert_equal [ "confirmation_required" ], result.errors
    assert_equal 11, result.removed_count
    assert people.all? { |person| person.reload.roster_removed_at.nil? }
    assert users.all? { |user| user.reload.disabled_at.nil? }
    assert result.roster_import.pending_csv.attached?
    assert_equal 11, result.roster_import.summary["removal_confirmation"]["removed_count"]
    assert_equal 11, result.roster_import.summary["removal_confirmation"]["sign_in_disable_count"]
    assert_equal true, result.roster_import.summary["removed_members"].all? { |member| member["would_disable_sign_in"] }
  end

  test "pending removal preview excludes the last enabled administrator from sign-in disable count" do
    keep = Person.create!(first_name: "Keep", last_name: "Admin", member_number: "000000000020", roster_imported_at: 1.day.ago)
    keep_user = User.create!(person: keep, email_address: "keep-admin@example.com")
    PermissionGrant.create!(user: keep_user, capability: "manage_settings")
    10.times do |index|
      person = Person.create!(first_name: "Remove", last_name: index.to_s, member_number: format("P%03d", index), roster_imported_at: 1.day.ago)
      User.create!(person: person, email_address: "remove#{index}@example.com")
    end

    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Still, Here",165,Member,1 A St,,still@example.com,555,Army,Vietnam,5,2026,Active
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "pending-admin.csv").import

    assert_equal "pending_confirmation", result.roster_import.status
    assert_equal 10, result.roster_import.summary["removal_confirmation"]["sign_in_disable_count"]
    removed_members = result.roster_import.summary["removed_members"]
    assert_equal false, removed_members.find { |member| member["member_number"] == "000000000020" }["would_disable_sign_in"]
    assert_equal true, removed_members.find { |member| member["member_number"] == "P000" }["would_disable_sign_in"]
  end

  test "pending removal preview reserves one removed admin when all enabled admins are being removed" do
    admin_a = Person.create!(first_name: "Admin", last_name: "A", member_number: "000000000030", roster_imported_at: 1.day.ago)
    admin_b = Person.create!(first_name: "Admin", last_name: "B", member_number: "000000000031", roster_imported_at: 1.day.ago)
    user_a = User.create!(person: admin_a, email_address: "admin-a@example.com")
    user_b = User.create!(person: admin_b, email_address: "admin-b@example.com")
    PermissionGrant.create!(user: user_a, capability: "manage_settings")
    PermissionGrant.create!(user: user_b, capability: "manage_settings")
    9.times do |index|
      person = Person.create!(first_name: "Remove", last_name: index.to_s, member_number: format("Q%03d", index), roster_imported_at: 1.day.ago)
      User.create!(person: person, email_address: "remove-q#{index}@example.com")
    end

    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Still, Here",165,Member,1 A St,,still@example.com,555,Army,Vietnam,5,2026,Active
    CSV

    result = RosterImports::Importer.new(csv_text: csv, filename: "pending-two-admins.csv").import

    assert_equal "pending_confirmation", result.roster_import.status
    assert_equal 10, result.roster_import.summary["removal_confirmation"]["sign_in_disable_count"]
    removed_members = result.roster_import.summary["removed_members"]
    admin_flags = removed_members.select { |member| %w[000000000030 000000000031].include?(member["member_number"]) }.map { |member| member["would_disable_sign_in"] }
    assert_equal 1, admin_flags.count(false)
    assert_equal 1, admin_flags.count(true)
  end

  test "confirmed large removal applies the stored import" do
    11.times do |index|
      person = Person.create!(first_name: "Gone", last_name: index.to_s, member_number: format("H%03d", index), roster_imported_at: 1.day.ago)
      User.create!(person: person, email_address: "confirm-gone#{index}@example.com")
    end
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Still, Here",165,Member,1 A St,,still@example.com,555,Army,Vietnam,5,2026,Active
    CSV
    pending = RosterImports::Importer.new(csv_text: csv, filename: "large-removal.csv").import.roster_import

    result = RosterImports::Importer.new(
      csv_text: pending.pending_csv.download,
      filename: pending.uploaded_filename,
      roster_import: pending,
      confirm_large_removal: true
    ).import

    assert result.success?
    assert_equal "completed", pending.reload.status
    assert_equal 11, Person.where.not(roster_removed_at: nil).count
    assert_equal 11, User.where.not(disabled_at: nil).count
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
