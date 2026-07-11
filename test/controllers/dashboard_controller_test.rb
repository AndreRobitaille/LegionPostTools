require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication after setup" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Installation.singleton.update!(setup_completed_at: Time.current)

    get root_path

    assert_redirected_to new_session_path
  end

  test "partial setup state still redirects to setup" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    get root_path

    assert_redirected_to new_setup_path
  end

  test "authenticated user sees dashboard" do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Andre", last_name: "Robitaille")
    user = User.create!(person: person, email_address: "andre@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Installation.singleton.update!(setup_completed_at: Time.current)
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "h1", organization.name
    assert_match "Signed in as #{person.full_name}", response.body
  end

  test "shows the passkey invite when the user has no passkeys" do
    user = signed_in_member
    get root_path
    assert_response :success
    assert_match "Add a passkey", response.body
  end

  test "hides the passkey invite when the user already has a passkey" do
    user = signed_in_member
    PasskeyCredential.create!(user: user, external_id: "cid", public_key: "pk", sign_count: 0)
    get root_path
    assert_response :success
    assert_no_match "Add a passkey", response.body
  end

  test "invite stays hidden after dismissal within the session" do
    signed_in_member
    delete passkey_invitation_path
    assert_redirected_to root_path

    get root_path
    assert_response :success
    assert_no_match "Add a passkey", response.body
  end

  private

  # A fully set-up, signed-in member with no passkeys yet.
  def signed_in_member
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Installation.singleton.update!(setup_completed_at: Time.current)
    sign_in_as(user)
    user
  end
end
