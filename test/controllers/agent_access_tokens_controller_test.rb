require "test_helper"

class AgentAccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Doe"), email_address: "jane@example.com")
    @other_user = User.create!(person: Person.create!(first_name: "Other", last_name: "Officer"), email_address: "other@example.com")
  end

  test "profile links to agent access and lists only the current user's tokens" do
    own, = AgentAccessToken.issue!(user: @user, name: "My Grok", expires_in: 90.days)
    AgentAccessToken.issue!(user: @other_user, name: "Someone else's Grok", expires_in: 90.days)
    sign_in_as(@user)

    get profile_path
    assert_select "a[href=?]", agent_access_tokens_path

    get agent_access_tokens_path
    assert_response :success
    assert_includes response.body, own.name
    assert_not_includes response.body, "Someone else's Grok"
    assert_select "textarea#agent-operator-instructions[readonly]", text: /You assist Jane Doe, a member of/
    assert_select "button", text: "Copy instructions"
  end

  test "creation requires authentication within ten minutes" do
    sign_in_as(@user, authenticated_at: 11.minutes.ago)

    assert_no_difference -> { AgentAccessToken.count } do
      post agent_access_tokens_path, params: { agent_access_token: { name: "Grok", expires_in_days: "90" } }
    end

    assert_redirected_to new_agent_access_reauthentication_path
  end

  test "recently authenticated user creates own expiring token and sees plaintext once" do
    sign_in_as(@user)

    assert_difference -> { @user.agent_access_tokens.count }, 1 do
      post agent_access_tokens_path, params: { agent_access_token: { name: "Grok Agent Computer", expires_in_days: "90" } }
    end

    assert_response :created
    token = @user.agent_access_tokens.last
    assert_in_delta 90.days.from_now, token.expires_at, 2.seconds
    assert_match(/lpt_/, response.body)
    plaintext = response.body[/lpt_[A-Za-z0-9_-]+_[A-Za-z0-9_-]+/]
    assert plaintext
    assert_equal "no-store", response.headers["Cache-Control"]

    get agent_access_tokens_path
    assert_not_includes response.body, plaintext
  end

  test "expiry choice is allowlisted" do
    sign_in_as(@user)

    assert_no_difference -> { AgentAccessToken.count } do
      post agent_access_tokens_path, params: { agent_access_token: { name: "Grok", expires_in_days: "3650" } }
    end

    assert_response :unprocessable_entity
  end

  test "user confirms and revokes only their own token" do
    own, = AgentAccessToken.issue!(user: @user, name: "My Grok", expires_in: 90.days)
    other, = AgentAccessToken.issue!(user: @other_user, name: "Other Grok", expires_in: 90.days)
    sign_in_as(@user)

    get revoke_agent_access_token_path(own)
    assert_response :success
    assert_select "form[action=?]", agent_access_token_path(own)

    delete agent_access_token_path(own)
    assert_redirected_to agent_access_tokens_path
    assert own.reload.revoked?

    delete agent_access_token_path(other)
    assert_response :not_found
    assert_not other.reload.revoked?
  end
end
