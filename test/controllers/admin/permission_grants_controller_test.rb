require "test_helper"

class Admin::PermissionGrantsControllerTest < ActionDispatch::IntegrationTest
  test "replaces user permissions from checked capabilities" do
    user = prepare_admin_user_with_permissions(%w[manage_settings manage_people])

    patch admin_user_permission_grants_path(user), params: { permission_grant: { capabilities: [ "manage_people", "approve_minutes" ] } }

    assert_redirected_to person_path(user.person)
    assert_equal "Permissions updated.", flash[:notice]
    assert_equal %w[approve_minutes manage_people], user.reload.permission_grants.order(:capability).pluck(:capability)
  end

  test "ignores invalid or unrecognized capabilities" do
    user = prepare_admin_user_with_permissions([])

    patch admin_user_permission_grants_path(user), params: { permission_grant: { capabilities: [ "manage_people", "not_real", "also_fake" ] } }

    assert_redirected_to person_path(user.person)
    assert_equal %w[manage_people], user.reload.permission_grants.order(:capability).pluck(:capability)
  end

  test "cannot remove last manage_settings grant from only enabled admin" do
    user = prepare_admin_user_with_permissions(%w[manage_settings manage_people], sign_in_as_target: true)

    patch admin_user_permission_grants_path(user), params: { permission_grant: { capabilities: [ "manage_people" ] } }

    assert_redirected_to person_path(user.person)
    assert_equal "At least one enabled administrator account is required.", flash[:alert]
    assert_equal %w[manage_people manage_settings], user.reload.permission_grants.order(:capability).pluck(:capability)
  end

  test "can remove manage_settings when another enabled admin exists" do
    user = prepare_admin_user_with_permissions(%w[manage_settings manage_people])
    other_person = Person.create!(first_name: "Other", last_name: "Admin")
    other_user = User.create!(person: other_person, email_address: "other@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: other_user, capability: "manage_settings")

    patch admin_user_permission_grants_path(user), params: { permission_grant: { capabilities: [ "manage_people" ] } }

    assert_redirected_to person_path(user.person)
    assert_equal "Permissions updated.", flash[:notice]
    assert_equal %w[manage_people], user.reload.permission_grants.order(:capability).pluck(:capability)
  end

  private

  def prepare_admin_user_with_permissions(capabilities, sign_in_as_target: false)
    prepare_setup_complete_state
    if sign_in_as_target
      person = sign_in_manage_settings_admin(first_name: "Vincent", last_name: "Alber", email_address: "vincent@example.com")
      user = person.user
    else
      sign_in_manage_settings_admin
      person = Person.create!(first_name: "Vincent", last_name: "Alber", roster_email_address: "vincent@example.com")
      user = User.create!(person: person, email_address: "vincent@example.com", email_verified_at: Time.current)
    end
    capabilities.uniq.each { |capability| PermissionGrant.create!(user:, capability:) unless user.permission_grants.exists?(capability: capability) }
    user
  end

  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_manage_settings_admin(first_name: "Jane", last_name: "Doe", email_address: "jane@example.com")
    person = Person.create!(first_name: first_name, last_name: last_name)
    user = User.create!(person: person, email_address: email_address, email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
    person
  end
end
