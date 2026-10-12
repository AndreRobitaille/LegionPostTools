require "test_helper"
require_relative "../support/buddy_checks_helpers"

class MobileAuthenticationTest < ActionDispatch::IntegrationTest
  include BuddyChecksHelpers
  setup do
    setup_buddy_checks
    @verifier = SecureRandom.urlsafe_base64(48)
    @authorization = { client_id: @mobile_client.uid, response_type: "code", scope: "buddy_check",
      redirect_uri: @mobile_client.redirect_uri, state: SecureRandom.hex(32),
      code_challenge_method: "S256", code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(@verifier), padding: false) }
  end
  teardown { restore_buddy_configuration }

  test "real email sign-in returns to consent and PKCE issues a scoped human credential" do
    get "/oauth/authorize", params: @authorization
    assert_redirected_to new_session_path
    magic_link = MagicLink.create_for!(@other)
    post magic_link_session_path, params: { token: magic_link.token }
    assert_response :redirect
    assert_includes response.location, "/oauth/authorize?"
    follow_redirect!
    assert_response :success
    assert_select "h1", "Connect Buddy Checks"
    post "/oauth/authorize", params: @authorization
    assert_response :redirect
    callback = URI.parse(response.location)
    returned = URI.decode_www_form(callback.query).to_h
    assert_equal @authorization[:state], returned["state"]
    assert_equal "org.example.buddy", callback.scheme
    exchange = { grant_type: "authorization_code", client_id: @mobile_client.uid, redirect_uri: @mobile_client.redirect_uri,
      code: returned.fetch("code"), code_verifier: @verifier }
    post "/oauth/token", params: exchange
    assert_response :success
    token = response.parsed_body.fetch("access_token")
    assert_equal 900, response.parsed_body["expires_in"]
    assert_nil response.parsed_body["refresh_token"]
    assert_not_equal token, Doorkeeper::AccessToken.sole.token
    get "/api/mobile/v1/session", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    assert_equal @other.id, response.parsed_body.dig("user", "id")
    assert_equal false, response.parsed_body.dig("capabilities", "refresh")
    post "/oauth/token", params: exchange
    assert_response :bad_request
    assert_equal 1, Doorkeeper::AccessToken.count
  end

  test "callbacks challenge methods state and issuer are validated before redirecting" do
    sign_in_as(@other)
    [ { redirect_uri: "org.evil:/callback" }, { redirect_uri: "#{@mobile_client.redirect_uri}?extra=1" },
      { code_challenge_method: "plain" }, { code_challenge: "bad" }, { state: "" }, { response_type: "token" } ].each do |change|
      get "/oauth/authorize", params: @authorization.merge(change)
      assert_response :bad_request
      assert_nil response.headers["Location"]
    end
    host! "wrong.example.com"
    get "/oauth/authorize", params: @authorization
    assert_response :bad_request
    assert_equal 0, Doorkeeper::AccessGrant.count
  end

  test "wrong verifier callback expired code and disabled user cannot exchange a code" do
    sign_in_as(@other)
    post "/oauth/authorize", params: @authorization
    code = URI.decode_www_form(URI.parse(response.location).query).to_h.fetch("code")
    exchange = { grant_type: "authorization_code", client_id: @mobile_client.uid, redirect_uri: @mobile_client.redirect_uri, code:, code_verifier: @verifier }
    post "/oauth/token", params: exchange.merge(code_verifier: "x" * 64)
    assert_response :bad_request
    post "/oauth/token", params: exchange.merge(redirect_uri: "org.evil:/callback")
    assert_response :bad_request
    @other.update!(disabled_at: Time.current)
    post "/oauth/token", params: exchange
    assert_response :bad_request
    @other.update!(disabled_at: nil)
    travel 11.minutes do
      post "/oauth/token", params: exchange
      assert_response :bad_request
    end
    assert_equal 0, Doorkeeper::AccessToken.count
  end

  test "expiry and both device and browser revocation invalidate subsequent requests" do
    headers = mobile_headers
    get "/api/mobile/v1/session", headers: headers
    assert_response :success
    travel 16.minutes do
      get "/api/mobile/v1/session", headers: headers
      assert_response :unauthorized
      assert_equal "expired_session", response.parsed_body.dig("error", "code")
    end
    post "/oauth/revoke", params: { client_id: @mobile_client.uid, token: @mobile_tokens[@other.id].plaintext_token }
    assert_response 200
    get "/api/mobile/v1/session", headers: headers
    assert_response :unauthorized
    assert_equal "revoked_session", response.parsed_body.dig("error", "code")
    @mobile_tokens.clear
    headers = mobile_headers
    sign_in_as(@other)
    get "/mobile/sessions"
    assert_response :success
    delete "/mobile/sessions/#{@mobile_tokens[@other.id].id}"
    assert_response :redirect
    get "/api/mobile/v1/session", headers: headers
    assert_response :unauthorized
    assert_equal "revoked_session", response.parsed_body.dig("error", "code")
  end

  test "email code sign-in in a fresh browser retains the OAuth request through delivery and consent" do
    get "/oauth/authorize", params: @authorization
    assert_redirected_to new_session_path
    assert_emails 1 do
      post session_path, params: { email_address: @other.email_address }
    end
    assert_redirected_to code_session_path
    delivered = ActionMailer::Base.deliveries.last
    assert_equal [ @other.email_address ], delivered.to
    assert_includes delivered.text_part.body.to_s, "/session/magic_link?token="
    code = delivered.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    assert code.present?
    assert_equal 0, Doorkeeper::AccessGrant.count
    post code_session_path, params: { code: }
    assert_response :redirect
    follow_redirect!
    assert_response 200
    assert_select "h1", "Connect Buddy Checks"
    assert_equal 0, Doorkeeper::AccessGrant.count
    post "/oauth/authorize", params: @authorization
    code = URI.decode_www_form(URI.parse(response.location).query).to_h.fetch("code")
    post "/oauth/token", params: { grant_type: "authorization_code", client_id: @mobile_client.uid,
      redirect_uri: @mobile_client.redirect_uri, code:, code_verifier: @verifier }
    assert_response 200
    assert_equal @other.id, Doorkeeper::AccessToken.sole.resource_owner_id
    assert_nil Doorkeeper::AccessToken.sole.refresh_token
  end

  test "consent response limits referrers to the origin and forbids caching" do
    sign_in_as(@other)
    get "/oauth/authorize", params: @authorization
    assert_response :success
    assert_equal "strict-origin", response.headers["Referrer-Policy"]
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "pilot authority is required for consent exchange and later use of an existing credential" do
    headers = mobile_headers
    sign_in_as(@other)
    post "/oauth/authorize", params: @authorization
    code = URI.decode_www_form(URI.parse(response.location).query).to_h.fetch("code")
    @other.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    get "/oauth/authorize", params: @authorization
    assert_select "input[type='submit'][value='Connect Buddy Checks']", count: 0
    assert_nil response.headers["Location"]
    post "/oauth/authorize", params: @authorization
    assert_nil response.headers["Location"]
    assert_equal 1, Doorkeeper::AccessGrant.count
    post "/oauth/token", params: { grant_type: "authorization_code", client_id: @mobile_client.uid,
      redirect_uri: @mobile_client.redirect_uri, code:, code_verifier: @verifier }
    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    get "/api/mobile/v1/session", headers: headers
    assert_response :forbidden
    assert_equal "account_unavailable", response.parsed_body.dig("error", "code")
    assert_equal 1, Doorkeeper::AccessToken.count
    assert_equal 0, BuddyOperation.count
  end

  test "pilot capability from a configured office ends with the dated assignment" do
    @officer.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    PositionCapabilityGrant.create!(position_title: @title, capability: "use_mobile_buddy_checks")
    headers = mobile_headers(@officer)
    get "/api/mobile/v1/session", headers: headers
    assert_response 200
    @office.update!(ends_on: Organization.current_local_date - 1)
    get "/api/mobile/v1/session", headers: headers
    assert_response :forbidden
    assert_equal "account_unavailable", response.parsed_body.dig("error", "code")
  end

  test "browser authorization rejects invalid CSRF tokens and origins and revocation retains CSRF protection" do
    previous = ActionController::Base.allow_forgery_protection
    previous_origin_check = ActionController::Base.forgery_protection_origin_check
    ActionController::Base.allow_forgery_protection = true
    ActionController::Base.forgery_protection_origin_check = true
    sign_in_as(@other)
    get "/oauth/authorize", params: @authorization
    assert_response :success
    csrf_token = Nokogiri::HTML(response.body).at_css("form[action='/oauth/authorize'] input[name='authenticity_token']")["value"]
    issuer = ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER")
    [ [ nil, issuer ], [ "wrong-token", issuer ], [ csrf_token, "https://unrelated.example" ], [ csrf_token, "null" ] ].each do |token, origin|
      assert_no_difference [ "Doorkeeper::AccessGrant.count", "Doorkeeper::AccessToken.count" ] do
        post "/oauth/authorize", params: @authorization.merge(authenticity_token: token).compact, headers: { "Origin" => origin }
        assert_response :unprocessable_entity
      end
    end
    mobile_headers
    delete "/mobile/sessions/#{@mobile_tokens[@other.id].id}"
    assert_response :unprocessable_entity
    assert_nil @mobile_tokens[@other.id].reload.revoked_at
  ensure
    ActionController::Base.allow_forgery_protection = previous
    ActionController::Base.forgery_protection_origin_check = previous_origin_check
  end
end
