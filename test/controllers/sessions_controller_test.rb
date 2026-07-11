require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "login request sends magic link for existing user" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)

    assert_emails 1 do
      post session_path, params: { email_address: user.email_address }
    end

    assert_redirected_to new_session_path
    assert_equal "Check your email for a login link.", flash[:notice]
  end

  test "magic link requests are rate limited by requester" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Installation.singleton.update!(setup_completed_at: Time.current)

    10.times do
      assert_emails 1 do
        post session_path, params: { email_address: user.email_address }
      end

      assert_redirected_to new_session_path
      assert_equal "Check your email for a login link.", flash[:notice]
    end

    assert_no_emails do
      post session_path, params: { email_address: user.email_address }
    end

    assert_redirected_to new_session_path
    assert_equal "Please wait a few minutes and try again.", flash[:alert]
  end

  test "magic link requests for different accounts from one requester are throttled independently" do
    Installation.singleton.update!(setup_completed_at: Time.current)
    first = User.create!(person: Person.create!(first_name: "First", last_name: "Officer"), email_address: "first@example.com", email_verified_at: Time.current)
    second = User.create!(person: Person.create!(first_name: "Second", last_name: "Officer"), email_address: "second@example.com", email_verified_at: Time.current)

    # Exhaust the first account's bucket (same requester IP).
    10.times { post session_path, params: { email_address: first.email_address } }
    post session_path, params: { email_address: first.email_address }
    assert_equal "Please wait a few minutes and try again.", flash[:alert]

    # A different account from the same IP still gets through.
    assert_emails 1 do
      post session_path, params: { email_address: second.email_address }
    end
    assert_equal "Check your email for a login link.", flash[:notice]
  end

  test "magic link callback signs in" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Installation.singleton.update!(setup_completed_at: Time.current)
    magic_link = MagicLink.create_for!(user)

    get magic_link_session_path(token: magic_link.token)

    assert_response :success
    assert_no_difference -> { Session.count } do
      get magic_link_session_path(token: magic_link.token)
    end

    assert_nil magic_link.reload.used_at

    assert_difference -> { Session.count }, 1 do
      post magic_link_session_path, params: { token: magic_link.token }
    end

    assert_redirected_to root_path
    assert Session.exists?(user: user)

    follow_redirect!

    assert_response :success
    assert_match "LegionPostTools", response.body
    assert_match user.person.full_name, response.body
  end

  test "magic link consumption is rate limited by requester" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Installation.singleton.update!(setup_completed_at: Time.current)

    30.times do
      post magic_link_session_path, params: { token: "invalid-token" }
      assert_redirected_to new_session_path
      assert_equal "That login link is invalid or expired.", flash[:alert]
    end

    post magic_link_session_path, params: { token: "invalid-token" }

    assert_redirected_to new_session_path
    assert_equal "Please wait a few minutes and try again.", flash[:alert]
  end

  test "magic link display is not rate limited" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Installation.singleton.update!(setup_completed_at: Time.current)
    magic_link = MagicLink.create_for!(user)

    11.times do
      get magic_link_session_path(token: magic_link.token)

      assert_response :success
    end
  end

  test "HEAD magic link does not consume token or create session" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Installation.singleton.update!(setup_completed_at: Time.current)
    magic_link = MagicLink.create_for!(user)

    assert_no_difference -> { Session.count } do
      head magic_link_session_path(token: magic_link.token)
    end

    assert_nil magic_link.reload.used_at
  end

  test "disabled user after link issuance cannot sign in" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    magic_link = MagicLink.create_for!(user)
    user.update!(disabled_at: Time.current)

    assert_no_difference -> { Session.count } do
      post magic_link_session_path, params: { token: magic_link.token }
    end

    assert_redirected_to new_session_path
  end

  test "disabled user session is destroyed on resume" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    session = Session.create!(user: user, ip_address: "127.0.0.1", user_agent: "test", last_seen_at: Time.current)
    user.update!(disabled_at: Time.current)

    request = ActionDispatch::TestRequest.create
    request.cookie_jar.signed[:session_id] = session.id

    get new_session_path, headers: { "Cookie" => request.cookie_jar.to_header }

    assert_nil Current.session
    assert_not Session.exists?(session.id)
  end
end
