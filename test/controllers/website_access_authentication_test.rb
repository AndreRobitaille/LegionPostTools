require "test_helper"
require_relative "../support/website_publishing_support"

class WebsiteAccessAuthenticationTest < ActionDispatch::IntegrationTest
  include WebsitePublishingSupport

  setup do
    setup_publisher
    Installation.singleton.update!(setup_completed_at: Time.current)
    @token, secret = WebsiteAccessToken.issue!(organization: @organization, actor: @publisher, name: "Website")
    @headers = { "Authorization" => "Bearer #{secret}" }
    @story = story
    feature(@story)
    @event = event_publication
    @portrait = "/public/v1/member_stories/#{@story.public_id}/portrait/#{@story.snapshot['portrait_revision']}/small.webp"
    @paths = [ "/public/v1/featured_members", "/public/v1/member_stories/#{@story.public_id}",
      "/public/v1/events?from=2026-10-01&to=2026-11-01", "/public/v1/events/#{@event.public_id}",
      @portrait, "/public/v1/unknown" ]
  end
  teardown { teardown_publisher }

  test "all feed routes and methods reject anonymous access before resource lookup" do
    @paths.each do |path|
      %i[get head post put patch delete options].each do |method|
        public_send(method, path)
        assert_response :unauthorized
        assert_equal "no-store", response.headers["Cache-Control"]
        assert_equal 'Bearer realm="website"', response.headers["WWW-Authenticate"]
        assert_equal "Authorization", response.headers["Vary"]
        assert_nil response.headers["ETag"]
      end
    end
  end

  test "sessions personal tokens query credentials and malformed headers cannot read website content" do
    sign_in_as(@publisher)
    _, personal_secret = AgentAccessToken.issue!(user: @publisher, name: "Personal", expires_in: 1.day)
    [ {}, { "Authorization" => "Bearer #{personal_secret}" }, { "Authorization" => "Bearer invalid" },
      { "Authorization" => @headers["Authorization"].sub("Bearer", "Basic") } ].each do |headers|
      get "/public/v1/featured_members", headers: headers
      assert_response :unauthorized
    end
    get "/public/v1/featured_members", params: { token: @headers["Authorization"].delete_prefix("Bearer ") }
    assert_response :unauthorized
  end

  test "revoked tokens cannot read collections details portraits HEAD or conditional responses" do
    etags = @paths.excluding("/public/v1/unknown").to_h do |path|
      get path, headers: @headers
      assert_response :success
      assert_equal %w[max-age=300 must-revalidate private], response.headers["Cache-Control"].split(", ").sort
      assert_equal "Authorization", response.headers["Vary"]
      [ path, response.headers["ETag"] ]
    end
    @token.revoke!(@publisher)
    etags.each do |path, etag|
      %i[get head].each do |method|
        public_send(method, path, headers: @headers.merge("If-None-Match" => etag))
        assert_response :unauthorized
        assert_equal "no-store", response.headers["Cache-Control"]
        assert_nil response.headers["ETag"]
      end
    end
  end

  test "tokens select their own Post and cannot read another Post identities or portraits" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/New_York")
    _, secret = WebsiteAccessToken.issue!(organization: other, actor: @publisher, name: "Other website")
    headers = { "Authorization" => "Bearer #{secret}" }
    get "/public/v1/featured_members", headers: headers
    assert_response :success
    assert_empty response.parsed_body["members"]
    get "/public/v1/events?from=2026-10-01&to=2026-11-01", headers: headers
    assert_empty response.parsed_body["events"]
    assert_equal "America/New_York", response.parsed_body["timezone"]
    [ @paths[1], @paths[3], @portrait ].each do |path|
      get path, headers: headers
      assert_response :not_found
    end
  end

  test "website token has no private API or editorial authority even alongside a signed-in publisher" do
    sign_in_as(@publisher)
    [ "/api", "/api/people", "/api/calendar_events", "/api/website_publications" ].each do |path|
      get path, headers: @headers
      assert_response :unauthorized
    end
    assert_no_difference "WebsitePublication.count" do
      post "/api/website_publications", headers: @headers.merge("Idempotency-Key" => SecureRandom.uuid), params: {}, as: :json
    end
    assert_response :unauthorized
    post "/public/v1/events", headers: @headers
    assert_response :method_not_allowed
  end
end
