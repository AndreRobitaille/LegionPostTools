require "application_system_test_case"

class AgentAccessTokensSystemTest < ApplicationSystemTestCase
  setup do
    Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)

    system_sign_in(@user)
  end

  test "member creates, sees once, and revokes a personal agent token" do
    visit profile_path
    click_link "Manage agent access"
    click_link "Create an agent token"

    fill_in "Token name", with: "Grok meeting helper"
    select "30 days", from: "Expires after"
    click_button "Create token"

    assert_selector "h1", text: "Copy your agent token now"
    assert_button "Copy token"
    plaintext = find("#issued-agent-token").value
    assert_match(/\Alpt_[0-9a-f]{24}_[0-9a-f]{64}\z/, plaintext)
    assert_text "This is the only time the complete token will be shown."

    click_link "I have stored it"
    assert_selector ".agent-token-name", text: "Grok meeting helper"
    assert_no_selector "#issued-agent-token"

    page.go_back
    assert_no_selector "#issued-agent-token"
    assert_no_text plaintext

    visit agent_access_tokens_path
    page.current_window.resize_to(390, 844)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    click_link "Revoke"
    assert_selector "h1", text: "Revoke Grok meeting helper?"
    click_button "Revoke token"

    assert_selector ".agent-token-status", text: "Revoked"
    assert_predicate @user.agent_access_tokens.last.reload, :revoked?
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
