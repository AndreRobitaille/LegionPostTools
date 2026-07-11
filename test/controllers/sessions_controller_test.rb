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

  test "magic link callback signs in" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    magic_link = MagicLink.create_for!(user)

    get magic_link_session_path(token: magic_link.token)

    assert_redirected_to root_path
    assert Session.exists?(user: user)
  end
end
