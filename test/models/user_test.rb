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
  end

  test "set_login_access_override! stores disabled false state" do
    user = User.create!(person: Person.create!(first_name: "Enable", last_name: "Override"), email_address: "enable@example.com", disabled_at: 1.day.ago)

    user.set_login_access_override!(disabled: false)

    user.reload
    assert user.login_access_override?
    assert user.login_access_override_at.present?
    assert_nil user.disabled_at
  end

  test "roster controlled access enables active and grace members" do
    %w[Active grace].each do |status|
      person = Person.create!(first_name: status, last_name: "Member", roster_member_status: status)
      user = User.create!(person: person, email_address: "#{status.downcase}@example.com", disabled_at: 1.day.ago)

      assert_equal :enabled_by_roster_status, user.apply_roster_access!
      assert_nil user.reload.disabled_at
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
  end

  test "roster controlled access skips admin override accounts" do
    user = User.create!(
      person: Person.create!(first_name: "Override", last_name: "Member", roster_member_status: "Expired"),
      email_address: "override@example.com",
      login_access_override: true,
      login_access_override_at: Time.current
    )

    assert_equal :skipped_admin_override, user.apply_roster_access!
    assert_nil user.reload.disabled_at
  end

  test "unsupported status returns :unsupported_status and does not change sign-in" do
    user = User.create!(
      person: Person.create!(first_name: "Unknown", last_name: "Member", roster_member_status: "Suspended"),
      email_address: "unknown@example.com"
    )

    assert_equal :unsupported_status, user.apply_roster_access!
    assert_nil user.reload.disabled_at
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
      person: Person.create!(first_name: "Back", last_name: "Policy", roster_member_status: "Expired"),
      email_address: "back-policy@example.com",
      login_access_override: true,
      login_access_override_at: Time.current
    )

    assert_equal :disabled_by_roster_status, user.return_to_roster_control!
    user.reload
    assert_not user.login_access_override?
    assert_nil user.login_access_override_at
    assert user.disabled_at.present?
  end

  test "return_to_roster_control skips when user is last enabled admin and override remains set" do
    person = Person.create!(first_name: "Sole", last_name: "Admin", roster_member_status: "Expired")
    user = User.create!(person: person, email_address: "sole-admin@example.com", login_access_override: true, login_access_override_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")

    assert_equal :skipped_last_admin, user.return_to_roster_control!
    user.reload
    assert user.login_access_override?
    assert user.login_access_override_at.present?
    assert_nil user.disabled_at
  end
end
