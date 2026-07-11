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

    request = ActionDispatch::TestRequest.create
    request.cookie_jar.signed[:session_id] = session.id

    options = Struct.new(:challenge) do
      def as_json(*)
        { challenge: challenge, user: { id: "1", name: "jane@example.com", display_name: "Jane Doe" } }
      end
    end.new("challenge-token")

    original = WebAuthn::Credential.method(:options_for_create)
    WebAuthn::Credential.define_singleton_method(:options_for_create) { |*| options }

    begin
      post registration_options_passkeys_path, headers: { "Cookie" => request.cookie_jar.to_header }

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal "challenge-token", payload["challenge"]
      assert_equal({ "id" => "1", "name" => "jane@example.com", "display_name" => "Jane Doe" }, payload["user"])
    ensure
      WebAuthn::Credential.define_singleton_method(:options_for_create, original)
    end
  end
end
