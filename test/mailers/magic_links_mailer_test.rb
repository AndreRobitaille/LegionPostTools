require "test_helper"

class MagicLinksMailerTest < ActionMailer::TestCase
  test "login email addresses the member and carries the link, button, and expiry" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    url = "https://example.test/session/magic_link?token=abc123"

    email = MagicLinksMailer.login(user, url)

    assert_equal ["jane@example.com"], email.to
    assert_equal "Sign in to LegionPostTools", email.subject

    html = email.html_part.body.to_s
    text = email.text_part.body.to_s

    assert_match "Jane Doe", html
    assert_match url, html
    assert_match "Sign in", html            # the button label
    assert_match "15 minutes", html
    assert_match(/copy and paste/i, html)   # plain-URL fallback for the branded email
    assert_match url, text
    assert_match "15 minutes", text
  end
end
