require "test_helper"

class MagicLinksMailerTest < ActionMailer::TestCase
  test "login email addresses the member and carries the link, button, and expiry" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    url = "https://example.test/session/magic_link?token=abc123"

    email = MagicLinksMailer.login(user, url, "1234 5678")

    assert_equal [ "jane@example.com" ], email.to
    assert_equal "Sign in to LegionPostTools", email.subject

    html = email.html_part.body.to_s
    text = email.text_part.body.to_s

    assert_match "Jane Doe", html
    assert_match url, html
    assert_match "Sign in", html            # the button label
    assert_match "15 minutes", html
    assert_match "1234 5678", html
    assert_match(/copy and paste/i, html)   # plain-URL fallback for the branded email
    assert_match url, text
    assert_match "1234 5678", text
    assert_match "15 minutes", text
  end

  test "agent access confirmation email is code-only and purpose-specific" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)

    email = MagicLinksMailer.agent_access_confirmation(user, "1234 5678")

    assert_equal [ "jane@example.com" ], email.to
    assert_equal "Confirm agent access in LegionPostTools", email.subject

    html = email.html_part.body.to_s
    text = email.text_part.body.to_s

    assert_match "Jane Doe", html
    assert_match "1234 5678", html
    assert_match "creating an agent access token", html
    assert_match "15 minutes", text
    assert_no_match(/sign[ -]in link/i, html)
    assert_no_match(%r{/session/magic_link}, html)
    assert_no_match(%r{https?://}, text)
  end
end
