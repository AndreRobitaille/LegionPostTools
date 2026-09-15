require "test_helper"
require "webauthn/fake_client"

class PasskeyEnrollmentSecurityTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Enrollment Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Enrollment", last_name: "Member"),
      email_address: "enrollment@example.com", email_verified_at: Time.current)
    @client = WebAuthn::FakeClient.new("http://localhost:3000")
  end

  test "stale and legacy sessions cannot issue or submit enrollment" do
    [ 1.hour.ago, nil ].each do |authenticated_at|
      session_record = sign_in_as(@user, authenticated_at: authenticated_at)
      stored_authenticated_at = session_record.reload.authenticated_at

      assert_no_difference "PasskeyCredential.count" do
        post registration_options_passkeys_path
        assert_response :forbidden
        assert_equal new_passkey_enrollment_reauthentication_path, response.parsed_body["confirmation_url"]
        post registration_passkeys_path, params: { publicKeyCredential: @client.create(user_verified: true) }
        assert_response :forbidden
      end
      if stored_authenticated_at
        assert_equal stored_authenticated_at, session_record.reload.authenticated_at
      else
        assert_nil session_record.reload.authenticated_at
      end
      assert_not session_record.recently_authenticated?
    end
  end

  test "fresh session can enroll first passkey without refreshing its identity proof" do
    session_record = sign_in_as(@user, authenticated_at: 5.minutes.ago)
    authenticated_at = session_record.reload.authenticated_at
    credential = enrollment_credential

    assert_difference "@user.passkey_credentials.count", 1 do
      post registration_passkeys_path, params: { publicKeyCredential: credential, nickname: "Home" }
      assert_response :created
    end
    assert_equal "Home", @user.passkey_credentials.last.nickname
    assert_equal authenticated_at, session_record.reload.authenticated_at

    assert_no_difference "PasskeyCredential.count" do
      post registration_passkeys_path, params: { publicKeyCredential: credential }
      assert_response :unprocessable_entity
    end
  end

  test "challenge issued while recent cannot complete after identity expires" do
    sign_in_as(@user)
    credential = enrollment_credential
    travel 11.minutes do
      assert_no_difference "PasskeyCredential.count" do
        post registration_passkeys_path, params: { publicKeyCredential: credential }
        assert_response :forbidden
      end
    end
  end

  test "reauthentication invalidates previously issued enrollment challenge" do
    session_record = sign_in_as(@user, authenticated_at: 5.minutes.ago)
    credential = enrollment_credential
    session_record.reauthenticate!

    assert_no_difference "PasskeyCredential.count" do
      post registration_passkeys_path, params: { publicKeyCredential: credential }
      assert_response :unprocessable_entity
    end
    credential = enrollment_credential
    post registration_passkeys_path, params: { publicKeyCredential: credential }
    assert_response :created
  end

  test "challenge cannot move to another recent session for the same user" do
    sign_in_as(@user)
    credential = enrollment_credential
    sign_in_as(@user)

    assert_no_difference "PasskeyCredential.count" do
      post registration_passkeys_path, params: { publicKeyCredential: credential }
      assert_response :unprocessable_entity
    end
  end

  test "fresh session must issue its own challenge before submitting a credential" do
    sign_in_as(@user)
    assert_no_difference "PasskeyCredential.count" do
      post registration_passkeys_path, params: { publicKeyCredential: @client.create(user_verified: true) }
      assert_response :unprocessable_entity
    end
  end

  test "denied attacker key cannot be used to turn stale access into fresh sign in" do
    session_record = sign_in_as(@user, authenticated_at: 1.hour.ago)
    attacker_key = @client.create(user_verified: true)
    post registration_passkeys_path, params: { publicKeyCredential: attacker_key }
    assert_response :forbidden
    post authentication_options_passkeys_path
    assertion = @client.get(challenge: response.parsed_body["challenge"], user_verified: true)
    assert_no_difference "Session.count" do
      post authentication_passkeys_path, params: { publicKeyCredential: assertion }
      assert_response :unauthorized
    end
    assert_not session_record.reload.recently_authenticated?
  end

  test "email sign in restores enrollment for a member without an existing passkey" do
    sign_in_as(@user, authenticated_at: 1.hour.ago)
    post registration_options_passkeys_path
    assert_response :forbidden
    get response.parsed_body["confirmation_url"]
    assert_response :success
    assert_select ".panel-lead", text: /Before adding a new passkey/

    link = MagicLink.create_for!(@user)
    post magic_link_session_path(token: link.token)
    credential = enrollment_credential
    post registration_passkeys_path, params: { publicKeyCredential: credential }
    assert_response :created
  end

  test "existing passkey sign in restores enrollment" do
    sign_in_as(@user)
    post registration_passkeys_path, params: { publicKeyCredential: enrollment_credential }
    assert_response :created
    sign_in_as(@user, authenticated_at: 1.hour.ago)
    post authentication_options_passkeys_path
    assertion = @client.get(challenge: response.parsed_body["challenge"], user_verified: true)
    post authentication_passkeys_path, params: { publicKeyCredential: assertion }
    assert_response :success
    post registration_options_passkeys_path
    assert_response :success
    assert_equal 1, response.parsed_body["excludeCredentials"].size
  end

  test "existing passkey confirms enrollment in the same session and preserves the name" do
    sign_in_as(@user)
    post registration_passkeys_path, params: { publicKeyCredential: enrollment_credential }
    assert_response :created
    session_record = sign_in_as(@user, authenticated_at: 1.hour.ago)
    post registration_options_passkeys_path, params: { nickname: "Second device" }
    get new_passkey_enrollment_reauthentication_path
    post authentication_options_passkeys_path
    assertion = @client.get(challenge: response.parsed_body["challenge"], user_verified: true)
    assert_no_difference "Session.count" do
      post authentication_passkeys_path, params: { publicKeyCredential: assertion }
      assert_response :success
    end
    assert session_record.reload.recently_authenticated?
    get profile_path
    assert_select "input#new-passkey-nickname[value=?]", "Second device"
    assert_select "button", text: "Continue adding your passkey"
    post registration_passkeys_path, params: { publicKeyCredential: enrollment_credential, nickname: "Second device" }
    assert_response :created
    get profile_path
    assert_select "input#new-passkey-nickname[value='']"
  end

  test "another members passkey cannot confirm enrollment" do
    sign_in_as(@user)
    post registration_passkeys_path, params: { publicKeyCredential: enrollment_credential }
    another_user = User.create!(person: Person.create!(first_name: "Other", last_name: "Member"), email_address: "other@example.com")
    session_record = sign_in_as(another_user, authenticated_at: 1.hour.ago)
    post registration_options_passkeys_path
    get new_passkey_enrollment_reauthentication_path
    post authentication_options_passkeys_path
    assertion = @client.get(challenge: response.parsed_body["challenge"], user_verified: true)
    post authentication_passkeys_path, params: { publicKeyCredential: assertion }
    assert_response :unauthorized
    assert_not session_record.reload.recently_authenticated?
  end

  private

  def enrollment_credential
    post registration_options_passkeys_path
    assert_response :success
    @client.create(challenge: response.parsed_body["challenge"], user_verified: true)
  end
end
