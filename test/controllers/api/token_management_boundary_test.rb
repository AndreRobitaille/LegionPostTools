require "test_helper"

class ApiTokenManagementBoundaryTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @admin = User.create!(person: Person.create!(first_name: "Token", last_name: "Administrator"), email_address: "token-admin@example.test")
    @admin.permission_grants.create!(capability: "manage_settings")
    @personal, @personal_secret = AgentAccessToken.issue!(user: @admin, name: "Administrator agent", expires_in: 1.day)
    @website, @website_secret = WebsiteAccessToken.issue!(organization: @organization, actor: @admin, name: "Post website")
  end

  test "even an authenticated administrator has no token creation API" do
    sign_in_as(@admin)
    assert_no_difference [ "AgentAccessToken.count", "WebsiteAccessToken.count" ] do
      %w[agent_access_tokens website_access_tokens].each do |resource|
        post "/api/#{resource}", params: { name: "Not available" }, headers: bearer(@personal_secret), as: :json
        assert_response :not_found
      end
    end
  end

  test "administrator and website bearer tokens cannot authenticate token management screens" do
    [ @personal_secret, @website_secret ].each do |secret|
      headers = bearer(secret)
      [ new_agent_access_token_path, new_admin_website_access_token_path, admin_website_access_tokens_path ].each do |path|
        get path, headers: headers
        assert_redirected_to new_session_path
      end
      assert_no_difference [ "AgentAccessToken.count", "WebsiteAccessToken.count" ] do
        post agent_access_tokens_path, params: { agent_access_token: { name: "Not allowed", expires_in_days: "30" } }, headers: headers, as: :json
        assert_redirected_to new_session_path
        post admin_website_access_tokens_path, params: { website_access_token: { name: "Not allowed" } }, headers: headers, as: :json
        assert_redirected_to new_session_path
      end
      [ agent_access_token_path(@personal), admin_agent_access_token_path(@personal), admin_website_access_token_path(@website) ].each do |path|
        delete path, headers: headers, as: :json
        assert_redirected_to new_session_path
      end
      assert_not @personal.reload.revoked?
      assert_not @website.reload.revoked?
    end
  end

  private

  def bearer(secret)
    { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => SecureRandom.uuid }
  end
end
