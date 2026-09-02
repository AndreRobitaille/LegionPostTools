require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a unique person" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com")

    duplicate = User.new(person: person, email_address: "jane2@example.com")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:person_id], "has already been taken"
  end

  test "detects unresolved roster email mismatch" do
    person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
    user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

    assert user.roster_email_mismatch?
    assert user.needs_roster_email_review?
  end

  test "does not prompt again after keeping current login email for same roster email" do
    person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
    user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

    user.keep_current_login_email!

    assert user.roster_email_mismatch?
    assert_not user.needs_roster_email_review?
  end

  test "prompts again after remind me later" do
    person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
    user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

    user.remind_later_about_roster_email!

    assert user.needs_roster_email_review?
  end

  def admin(email)
    u = User.create!(person: Person.create!(first_name: email, last_name: "X"), email_address: "#{email}@x.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: u, capability: "manage_settings")
    u
  end

  test "only_enabled_administrator? is true when this is the sole enabled admin" do
    a = admin("a")
    assert a.only_enabled_administrator?
  end

  test "only_enabled_administrator? is false when another enabled admin exists" do
    a = admin("a")
    admin("b")
    assert_not a.only_enabled_administrator?
  end

  test "another_enabled_manage_settings_user_exists? ignores the given user and disabled users" do
    a = admin("a")
    b = admin("b")
    assert User.another_enabled_manage_settings_user_exists?(a)
    b.update!(disabled_at: Time.current)
    assert_not User.another_enabled_manage_settings_user_exists?(a)
  end

  test "login access override defaults to false" do
    user = User.create!(person: Person.create!(first_name: "No", last_name: "Override"), email_address: "no-override@example.com")

    assert_not user.login_access_override?
    assert_nil user.login_access_override_at
  end

  test "set_login_access_override! stores disabled true state" do
    user = User.create!(person: Person.create!(first_name: "Disable", last_name: "Override"), email_address: "disable@example.com")

    user.set_login_access_override!(disabled: true)

    user.reload
    assert user.login_access_override?
    assert user.login_access_override_at.present?
    assert user.disabled_at.present?
    assert_equal "manual", user.disabled_reason
    assert_nil user.disabled_reason_detail
  end

  test "set_login_access_override! stores disabled false state" do
    user = User.create!(person: Person.create!(first_name: "Enable", last_name: "Override"), email_address: "enable@example.com", disabled_at: 1.day.ago)

    user.set_login_access_override!(disabled: false)

    user.reload
    assert user.login_access_override?
    assert user.login_access_override_at.present?
    assert_nil user.disabled_at
    assert_nil user.disabled_reason
  end

  test "roster controlled access enables active and grace members" do
    %w[Active grace].each do |status|
      person = Person.create!(first_name: status, last_name: "Member", roster_member_status: status)
      user = User.create!(person: person, email_address: "#{status.downcase}@example.com", disabled_at: 1.day.ago)

      assert_equal :enabled_by_roster_status, user.apply_roster_access!
      user.reload
      assert_nil user.disabled_at
      assert_nil user.disabled_reason
    end
  end

  test "roster controlled access disables expired deceased and removed members" do
    expired = User.create!(
      person: Person.create!(first_name: "Expired", last_name: "Member", roster_member_status: "Expired"),
      email_address: "expired@example.com"
    )
    deceased = User.create!(
      person: Person.create!(first_name: "Deceased", last_name: "Member", roster_member_status: "deceased"),
      email_address: "deceased@example.com"
    )
    removed = User.create!(
      person: Person.create!(first_name: "Removed", last_name: "Member", roster_member_status: "Active", roster_removed_at: Time.current),
      email_address: "removed@example.com"
    )

    assert_equal :disabled_by_roster_status, expired.apply_roster_access!
    assert_equal :disabled_by_roster_status, deceased.apply_roster_access!
    assert_equal :disabled_by_roster_status, removed.apply_roster_access!
    assert expired.reload.disabled_at.present?
    assert deceased.reload.disabled_at.present?
    assert removed.reload.disabled_at.present?
    assert_equal [ "roster_status", "expired" ], [ expired.disabled_reason, expired.disabled_reason_detail ]
    assert_equal [ "roster_status", "deceased" ], [ deceased.disabled_reason, deceased.disabled_reason_detail ]
    assert_equal "roster_removed", removed.disabled_reason
  end

  test "roster access replaces a legacy manual enable when member is no longer eligible" do
    user = User.create!(
      person: Person.create!(first_name: "Override", last_name: "Member", roster_member_status: "Expired"),
      email_address: "override@example.com",
      login_access_override: true,
      login_access_override_at: Time.current
    )

    assert_equal :disabled_by_roster_status, user.apply_roster_access!
    user.reload
    assert user.disabled_at.present?
    assert_equal "roster_status", user.disabled_reason
    assert_not user.login_access_override?
  end

  test "roster access preserves a deliberate manual disable for an active member" do
    user = User.create!(
      person: Person.create!(first_name: "Manual", last_name: "Disable", roster_member_status: "Active"),
      email_address: "manual-disable@example.com"
    )
    user.set_login_access_override!(disabled: true)

    assert_equal :skipped_manual_disable, user.apply_roster_access!
    user.reload
    assert user.disabled_at.present?
    assert_equal "manual", user.disabled_reason
    assert user.login_access_override?
  end

  test "unsupported roster status disables sign-in with the status as reason" do
    user = User.create!(
      person: Person.create!(first_name: "Unknown", last_name: "Member", roster_member_status: "Suspended"),
      email_address: "unknown@example.com"
    )

    assert_equal :disabled_by_roster_status, user.apply_roster_access!
    user.reload
    assert user.disabled_at.present?
    assert_equal "roster_status", user.disabled_reason
    assert_equal "suspended", user.disabled_reason_detail
  end

  test "last enabled administrator is not disabled by roster policy" do
    person = Person.create!(first_name: "Sole", last_name: "Admin", roster_member_status: "Expired")
    user = User.create!(person: person, email_address: "sole-admin@example.com")
    PermissionGrant.create!(user: user, capability: "manage_settings")

    assert_equal :skipped_last_admin, user.apply_roster_access!
    assert_nil user.reload.disabled_at
  end

  test "return_to_roster_control clears override and applies current roster policy" do
    user = User.create!(
      person: Person.create!(first_name: "Back", last_name: "Policy", member_number: "100", roster_member_status: "Expired"),
      email_address: "back-policy@example.com",
      login_access_override: true,
      login_access_override_at: Time.current
    )

    assert_equal :disabled_by_roster_status, user.return_to_roster_control!
    user.reload
    assert_not user.login_access_override?
    assert_nil user.login_access_override_at
    assert user.disabled_at.present?
    assert_equal "roster_status", user.disabled_reason
  end

  test "return_to_roster_control skips when user is last enabled admin and override remains set" do
    person = Person.create!(first_name: "Sole", last_name: "Admin", member_number: "101", roster_member_status: "Expired")
    user = User.create!(person: person, email_address: "sole-admin@example.com", login_access_override: true, login_access_override_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")

    assert_equal :skipped_last_admin, user.return_to_roster_control!
    user.reload
    assert user.login_access_override?
    assert user.login_access_override_at.present?
    assert_nil user.disabled_at
  end

  test "return_to_roster_control replaces a manual disable with the ineligible roster status" do
    user = User.create!(
      person: Person.create!(first_name: "Unknown", last_name: "Policy", member_number: "102", roster_member_status: "Suspended"),
      email_address: "unknown-policy@example.com"
    )
    user.set_login_access_override!(disabled: true)

    assert_equal :disabled_by_roster_status, user.return_to_roster_control!
    user.reload
    assert_not user.login_access_override?
    assert_equal "roster_status", user.disabled_reason
    assert_equal "suspended", user.disabled_reason_detail
    assert user.disabled_at.present?
  end

  test "manage_settings implies the management capabilities" do
    person = Person.create!(first_name: "Ada", last_name: "Admin")
    user = User.create!(person: person, email_address: "ada@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")

    assert user.can?("manage_agendas")
    assert user.can?("manage_people")
    assert user.can?("manage_meeting_bodies")
    assert user.can?("manage_minutes")
    assert user.can?("view_internal_records")
  end

  test "manage_settings does not imply the identity-bound attestation acts" do
    person = Person.create!(first_name: "Ada", last_name: "Admin")
    user = User.create!(person: person, email_address: "ada2@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")

    assert_not user.can?("attest_minutes")
    assert_not user.can?("approve_minutes")
    assert_not user.can?("record_minutes_approval")
  end

  test "a manage_agendas grant alone grants only manage_agendas" do
    person = Person.create!(first_name: "Sam", last_name: "Agenda")
    user = User.create!(person: person, email_address: "sam2@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_agendas")

    assert user.can?("manage_agendas")
    assert_not user.can?("manage_settings")
    assert_not user.can?("manage_people")
  end

  test "capabilities follow a current configured position assignment" do
    organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Current", last_name: "Adjutant")
    user = User.create!(person:, email_address: "current-adjutant@example.com")
    title = PositionTitle.create!(organization:, name: "Adjutant", display_order: 1)
    title.position_capability_grants.create!(capability: "manage_minutes")
    assignment = PositionAssignment.create!(person:, position_title: title, starts_on: Date.current - 1)

    assert user.can?("manage_minutes")
    assert_equal({ "manage_minutes" => [ "Adjutant" ] }, user.position_capability_sources)

    assignment.update!(ends_on: Date.current)
    assert user.can?("manage_minutes"), "the assignment remains active through its inclusive end date"

    assignment.update!(ends_on: Date.current - 1)
    assert_not user.can?("manage_minutes")
  end

  test "future and inactive positions do not grant capabilities" do
    organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Future", last_name: "Adjutant")
    user = User.create!(person:, email_address: "future-adjutant@example.com")
    title = PositionTitle.create!(organization:, name: "Adjutant", display_order: 1)
    title.position_capability_grants.create!(capability: "manage_minutes")
    assignment = PositionAssignment.create!(person:, position_title: title, starts_on: Date.current + 1)

    assert_not user.can?("manage_minutes")

    assignment.update!(starts_on: Date.current)
    title.update!(active: false)
    assert_not user.can?("manage_minutes")
  end

  test "manual permissions remain independent of position assignments" do
    person = Person.create!(first_name: "Former", last_name: "Officer")
    user = User.create!(person:, email_address: "former-officer@example.com")
    PermissionGrant.create!(user:, capability: "manage_minutes")

    assert user.can?("manage_minutes")
    assert_empty user.position_capability_sources
  end

  test "private agenda notes access follows current Commander and Adjutant authority" do
    organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    %w[approve_minutes attest_minutes].each_with_index do |capability, index|
      person = Person.create!(first_name: "Private", last_name: index.zero? ? "Commander" : "Adjutant")
      user = User.create!(person:, email_address: "private-notes-#{index}@example.com")
      title = PositionTitle.create!(organization:, name: "Role #{index}", display_order: index + 1)
      title.position_capability_grants.create!(capability:)
      assignment = title.position_assignments.create!(person:, starts_on: Date.current - 2)

      assert user.private_agenda_notes_access?

      assignment.update!(ends_on: Date.current - 1)
      assert_not user.private_agenda_notes_access?
    end
  end

  test "manual permissions do not grant private agenda notes access" do
    person = Person.create!(first_name: "Manual", last_name: "Agenda Manager")
    user = User.create!(person:, email_address: "manual-agenda-manager@example.com")
    %w[manage_settings manage_agendas approve_minutes attest_minutes].each do |capability|
      user.permission_grants.create!(capability:)
    end

    assert_not user.private_agenda_notes_access?
  end

  test "full membership access follows a current configured position assignment" do
    organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Current", last_name: "Commander")
    user = User.create!(person: person, email_address: "current-commander@example.com")
    title = PositionTitle.create!(
      organization: organization, name: "Membership Leader", display_order: 1,
      grants_full_membership_access: true
    )
    assignment = PositionAssignment.create!(person: person, position_title: title, starts_on: Date.current - 1)

    assert user.full_membership_access?

    assignment.update!(ends_on: Date.current)
    assert user.full_membership_access?, "the assignment remains active through its inclusive end date"

    assignment.update!(ends_on: Date.current - 1)
    assert_not user.full_membership_access?
  end

  test "future and inactive positions do not grant full membership access" do
    organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Future", last_name: "Officer")
    user = User.create!(person: person, email_address: "future-officer@example.com")
    title = PositionTitle.create!(
      organization: organization, name: "Future Leader", display_order: 1,
      grants_full_membership_access: true
    )
    assignment = PositionAssignment.create!(person: person, position_title: title, starts_on: Date.current + 1)

    assert_not user.full_membership_access?

    assignment.update!(starts_on: Date.current)
    title.update!(active: false)
    assert_not user.full_membership_access?
  end

  test "manage_people grants full membership access without a Post office" do
    person = Person.create!(first_name: "Membership", last_name: "Helper")
    user = User.create!(person: person, email_address: "membership-helper@example.com")
    PermissionGrant.create!(user: user, capability: "manage_people")

    assert user.full_membership_access?
  end
end
