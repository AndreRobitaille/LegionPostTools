require "test_helper"

class Admin::AgentAccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @admin = User.create!(person: Person.create!(first_name: "Admin", last_name: "Officer"), email_address: "admin@example.com")
    @admin.permission_grants.create!(capability: "manage_settings")
    @member = User.create!(person: Person.create!(first_name: "Member", last_name: "Officer"), email_address: "member@example.com")
    @token, @plaintext = AgentAccessToken.issue!(user: @member, name: "Member Grok", expires_in: 30.days)
  end

  test "administrator lists and revokes but cannot reveal or mint another user's token" do
    sign_in_as(@admin)

    get admin_agent_access_tokens_path
    assert_response :success
    assert_includes response.body, "Member Grok"
    assert_not_includes response.body, @plaintext

    delete admin_agent_access_token_path(@token)
    assert_redirected_to admin_agent_access_tokens_path
    assert @token.reload.revoked?
    assert_equal @admin, @token.revoked_by

    assert_no_difference -> { AgentAccessToken.count } do
      post admin_agent_access_tokens_path, params: { user_id: @member.id }
    end
    assert_response :not_found
  end

  test "ordinary member cannot oversee tokens" do
    sign_in_as(@member)

    get admin_agent_access_tokens_path

    assert_redirected_to root_path
  end
end
