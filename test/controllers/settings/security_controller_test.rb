require "test_helper"

class Settings::SecurityControllerTest < ActionDispatch::IntegrationTest
  setup do
    Installation.singleton.update!(setup_completed_at: Time.current)
    Organization.create!(name: "Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: @person, email_address: "jane@example.com", email_verified_at: Time.current)
  end

  test "requires authentication" do
    get settings_security_path
    assert_redirected_to new_session_path
  end

  test "lists the member's passkeys with nickname and dates" do
    PasskeyCredential.create!(user: @user, external_id: "cid1", public_key: "pk", sign_count: 0,
      nickname: "Kitchen iPad", last_used_at: Time.current)
    sign_in_as(@user)

    get settings_security_path

    assert_response :success
    assert_match "Security", response.body
    assert_match "Kitchen iPad", response.body
    assert_match "Add a passkey", response.body
  end

  test "shows an empty state when there are no passkeys" do
    sign_in_as(@user)
    get settings_security_path
    assert_response :success
    assert_match "no passkeys yet", response.body
  end
end
