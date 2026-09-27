require "test_helper"

class Admin::WebsiteAccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @admin = User.create!(person: Person.create!(first_name: "Admin", last_name: "Officer"), email_address: "admin@example.test")
    @admin.permission_grants.create!(capability: "manage_settings")
    @publisher = User.create!(person: Person.create!(first_name: "Content", last_name: "Editor"), email_address: "editor@example.test")
    @publisher.permission_grants.create!(capability: "publish_public_content")
  end

  test "administrator creates a Post credential sees it once and retains revocation audit" do
    sign_in_as(@admin)
    get admin_root_path
    assert_select "a[href=?]", admin_website_access_tokens_path
    assert_difference "WebsiteAccessToken.count", 1 do
      post admin_website_access_tokens_path, params: { website_access_token: { name: "Post website", created_by_id: @publisher.id, role: "commander" } }
    end
    assert_response :created
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
    secret = css_select("#issued-website-token").first.text
    token = WebsiteAccessToken.last
    assert_equal token, WebsiteAccessToken.authenticate(secret)
    assert_equal @organization, token.organization
    assert_equal @admin, token.created_by
    get admin_website_access_tokens_path
    assert_not_includes response.body, secret
    assert_select ".agent-token-status", text: /Active until revoked/
    get revoke_admin_website_access_token_path(token)
    assert_response :success
    assert_no_difference "WebsiteAccessToken.count" do
      delete admin_website_access_token_path(token)
    end
    assert_redirected_to admin_website_access_tokens_path
    assert_equal @admin, token.reload.revoked_by
    assert_nil WebsiteAccessToken.authenticate(secret)
  end

  test "anonymous clients and publishers cannot manage technical connections" do
    get admin_website_access_tokens_path
    assert_redirected_to new_session_path
    token, = WebsiteAccessToken.issue!(organization: @organization, actor: @admin, name: "Existing")
    sign_in_as(@publisher)
    get admin_website_access_tokens_path
    assert_redirected_to root_path
    get new_admin_website_access_token_path
    assert_redirected_to root_path
    assert_no_difference "WebsiteAccessToken.count" do
      post admin_website_access_tokens_path, params: { website_access_token: { name: "Unauthorized" } }
    end
    assert_redirected_to root_path
    delete admin_website_access_token_path(token)
    assert_redirected_to root_path
    assert_not token.reload.revoked?
  end

  test "old sessions confirm identity and return to website token creation" do
    sign_in_as(@admin, authenticated_at: 11.minutes.ago)
    assert_no_difference "WebsiteAccessToken.count" do
      post admin_website_access_tokens_path, params: { website_access_token: { name: "Website" } }
    end
    assert_redirected_to new_agent_access_reauthentication_path
    follow_redirect!
    assert_select ".page-sub", text: /website token/
    perform_enqueued_jobs { post agent_access_reauthentication_path }
    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    post verify_agent_access_reauthentication_path, params: { code: code }
    assert_redirected_to new_admin_website_access_token_path
    follow_redirect!
    assert_response :success
  end

  test "invalid names retain the form and other Post tokens cannot be managed" do
    sign_in_as(@admin)
    assert_no_difference "WebsiteAccessToken.count" do
      post admin_website_access_tokens_path, params: { website_access_token: { name: " " } }
    end
    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Name/
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    token, = WebsiteAccessToken.issue!(organization: other, actor: @admin, name: "Other website")
    get admin_website_access_tokens_path
    assert_not_includes response.body, "Other website"
    delete admin_website_access_token_path(token)
    assert_response :not_found
    assert_not token.reload.revoked?
  end

  test "creation and revocation enforce browser CSRF protection" do
    sign_in_as(@admin)
    token, = WebsiteAccessToken.issue!(organization: @organization, actor: @admin, name: "Existing")
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "WebsiteAccessToken.count" do
      post admin_website_access_tokens_path, params: { website_access_token: { name: "Forged" } }
    end
    assert_response :unprocessable_entity
    delete admin_website_access_token_path(token)
    assert_response :unprocessable_entity
    assert_not token.reload.revoked?
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
