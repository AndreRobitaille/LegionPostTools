require "test_helper"

class PasskeysControllerTest < ActionDispatch::IntegrationTest
  test "registration options require authentication" do
    post registration_options_passkeys_path

    assert_redirected_to new_session_path
  end

  test "authenticated user can request registration options" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    session = Session.create!(user: user, ip_address: "127.0.0.1", user_agent: "test", last_seen_at: Time.current)
    existing_credential = PasskeyCredential.create!(
      user: user,
      external_id: "existing-credential-id",
      public_key: "public-key",
      sign_count: 0
    )

    request = ActionDispatch::TestRequest.create
    request.cookie_jar.signed[:session_id] = session.id

    captured_args = nil
    options = Struct.new(:challenge) do
      def as_json(*)
        { challenge: challenge, user: { id: "1", name: "jane@example.com", display_name: "Jane Doe" } }
      end
    end.new("challenge-token")

    original = WebAuthn::Credential.method(:options_for_create)
    WebAuthn::Credential.singleton_class.send(:define_method, :options_for_create) do |**kwargs|
      captured_args = kwargs
      options
    end

    begin
      post registration_options_passkeys_path, headers: { "Cookie" => request.cookie_jar.to_header }

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal "challenge-token", payload["challenge"]
      assert_equal({ "id" => "1", "name" => "jane@example.com", "display_name" => "Jane Doe" }, payload["user"])
      assert_equal({
        user: {
          id: user.id.to_s,
          name: user.email_address,
          display_name: user.person.full_name
        },
        authenticator_selection: {
          resident_key: "required",
          user_verification: "required"
        },
        exclude: [existing_credential.external_id]
      }, captured_args)
    ensure
      WebAuthn::Credential.define_singleton_method(:options_for_create, original)
    end
  end

  test "authenticated user can complete passkey authentication" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    stored_credential = PasskeyCredential.create!(
      user: user,
      external_id: "credential-id",
      public_key: "public-key",
      sign_count: 3
    )

    session = Session.create!(user: user, ip_address: "127.0.0.1", user_agent: "test", last_seen_at: Time.current)
    request = ActionDispatch::TestRequest.create
    request.cookie_jar.signed[:session_id] = session.id

    credential = Object.new
    credential.define_singleton_method(:id) { "credential-id" }
    credential.define_singleton_method(:sign_count) { 4 }
    credential.define_singleton_method(:verify) do |challenge, public_key:, sign_count:, user_verification:|
      @verified_args = { challenge: challenge, public_key: public_key, sign_count: sign_count, user_verification: user_verification }
    end
    credential.define_singleton_method(:verified_args) { @verified_args }

    original = WebAuthn::Credential.method(:from_get)
    WebAuthn::Credential.singleton_class.send(:define_method, :from_get) do |*_args|
      credential
    end

    begin
      post authentication_passkeys_path,
        headers: {
          "Cookie" => request.cookie_jar.to_header,
        },
        params: { publicKeyCredential: { id: "credential-id" } }

      assert_response :success
      assert_equal({ "status" => "authenticated" }, JSON.parse(response.body))
      assert_equal({
        challenge: nil,
        public_key: "public-key",
        sign_count: 3,
        user_verification: true
      }, credential.verified_args)
      assert Session.exists?(user: user)
      assert_equal 4, stored_credential.reload.sign_count
      assert stored_credential.reload.last_used_at.present?
    ensure
      WebAuthn::Credential.define_singleton_method(:from_get, original)
    end
  end

  test "disabled user cannot authenticate with passkey" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current, disabled_at: Time.current)
    PasskeyCredential.create!(
      user: user,
      external_id: "credential-id",
      public_key: "public-key",
      sign_count: 1
    )

    credential = Struct.new(:id) do
      def verify(*)
        raise "should not verify disabled user"
      end
    end.new("credential-id")

    original = WebAuthn::Credential.method(:from_get)
    WebAuthn::Credential.singleton_class.send(:define_method, :from_get) do |*_args|
      credential
    end

    begin
      post authentication_passkeys_path, params: { publicKeyCredential: { id: "credential-id" } }

      assert_response :unauthorized
      assert_equal({ "error" => "invalid passkey authentication" }, JSON.parse(response.body))
    ensure
      WebAuthn::Credential.define_singleton_method(:from_get, original)
    end
  end
end
