require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @person = Person.create!(first_name: "Ann", last_name: "Roe")
    @user = User.create!(person: @person, email_address: "ann@example.com", email_verified_at: Time.current)
  end

  test "requires authentication" do
    get profile_path

    assert_redirected_to new_session_path
  end

  test "shows the member's own sign-in methods" do
    credential = @user.passkey_credentials.create!(external_id: "abc", public_key: "key", nickname: "Office laptop")
    sign_in_as(@user)

    get profile_path

    assert_response :success
    assert_select "h1", text: "Your profile"
    assert_select ".sec-head-label", text: "How you sign in"
    assert_select "input.pk-name-field[value=?]", credential.nickname
  end

  test "invites a first passkey when the member has none" do
    sign_in_as(@user)

    get profile_path

    assert_response :success
    assert_select ".pk-empty"
    assert_select "[data-passkey-redirect-value=?]", profile_path
  end

  test "links across to the post's own record of the member" do
    sign_in_as(@user)

    get profile_path

    assert_select ".profile-directory-link[href=?]", person_path(@person), text: "View your directory listing"
  end

  test "keeps personal agent access available to members" do
    sign_in_as(@user)

    get profile_path

    assert_select ".sec-head-label", text: "Agent access"
    assert_select "a[href=?]", agent_access_tokens_path, text: "Manage agent access"
  end

  test "shows only the signed-in member's passkeys" do
    other_person = Person.create!(first_name: "Bob", last_name: "Coe")
    other_user = User.create!(person: other_person, email_address: "bob@example.com", email_verified_at: Time.current)
    other_user.passkey_credentials.create!(external_id: "xyz", public_key: "key", nickname: "Bob's phone")
    sign_in_as(@user)

    get profile_path

    assert_response :success
    assert_select "input.pk-name-field[value=?]", "Bob's phone", count: 0
  end
end
