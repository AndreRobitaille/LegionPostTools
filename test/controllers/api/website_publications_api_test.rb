require "test_helper"
require_relative "../../support/website_publishing_support"

class ApiWebsitePublicationsTest < ActionDispatch::IntegrationTest
  include WebsitePublishingSupport

  setup do
    setup_publisher
    Installation.singleton.update!(setup_completed_at: Time.current)
    @token, @secret = AgentAccessToken.issue!(user: @publisher, name: "Synthetic editorial agent", expires_in: 1.day)
    @manager = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Manager"), email_address: "manager@example.test")
    @manager.permission_grants.create!(capability: "manage_settings")
  end
  teardown { teardown_publisher }

  test "every editorial route requires authentication and explicit publishing authority" do
    record = story
    routes = [ [ :get, "" ], [ :get, "/#{record.id}" ], [ :post, "" ], [ :patch, "/#{record.id}" ],
      [ :get, "/featured" ], [ :put, "/featured" ], [ :get, "/#{record.id}/history" ],
      [ :get, "/#{record.id}/portrait/#{record.draft['portrait_revision']}/small.webp" ] ]
    %w[portrait consent eligibility internal publish withdraw].each { |action| routes << [ :post, "/#{record.id}/#{action}" ] }
    routes.each do |method, suffix|
      public_send(method, "/api/website_publications#{suffix}", as: :json)
      assert_response :unauthorized
      assert_equal "no-store", response.headers["Cache-Control"]
    end
    sign_in_as(@manager)
    routes.each do |method, suffix|
      public_send(method, "/api/website_publications#{suffix}", as: :json)
      assert_response :forbidden
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "bearer story workflow prepares reviews publishes features and revokes with audit" do
    api(:post, "", {})
    assert_response :created
    @record = WebsitePublication.find(payload.fetch("id"))
    api(:patch, member_path, { lock_version: payload["lock_version"], draft: {
      display_name: "Avery (fictional)", introduction: "Synthetic introduction", story: "Synthetic story",
      conversation_starter: "Ask about the test", portrait_alt: "Blue test card"
    } })
    assert_response :success
    api(:post, "#{member_path}/portrait", { lock_version: payload["lock_version"], portrait_base64: Base64.strict_encode64(image_upload.read) })
    assert_response :success
    portrait_path = payload.dig("draft_portrait", "large")
    assert_not payload["consent_covers_draft"]
    api(:post, "#{member_path}/publish", { lock_version: payload["lock_version"] })
    assert_response :unprocessable_entity
    api(:post, "#{member_path}/consent", { lock_version: @record.reload.lock_version, note: "Fictional consent evidence supplied by test human" })
    assert_response :success
    assert payload["consent_covers_draft"]
    api(:post, "#{member_path}/publish", { lock_version: payload["lock_version"] })
    assert_response :success
    assert_equal "published", payload["status"]
    assert_equal @record.public_id, payload.dig("snapshot", "id")
    assert_not payload["draft"].key?("consent_draft")
    get portrait_path, headers: bearer
    assert_response :success
    assert_equal "image/webp", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal [ 640, 800 ], [ Vips::Image.new_from_buffer(response.body, "").width, Vips::Image.new_from_buffer(response.body, "").height ]
    api(:get, "/featured")
    selection = response.parsed_body.merge("public_ids" => [ @record.public_id ])
    api(:put, "/featured", selection)
    assert_response :success
    assert_equal [ @record.public_id ], response.parsed_body["public_ids"]
    _website_token, website_secret = WebsiteAccessToken.issue!(organization: @organization, actor: @manager, name: "Website")
    website_headers = { "Authorization" => "Bearer #{website_secret}" }
    get "/public/v1/featured_members", as: :json, headers: website_headers
    assert_response :success
    assert_includes response.body, @record.public_id
    api(:post, "#{member_path}/withdraw", { lock_version: 0, revoke_consent: true })
    assert_response :success
    assert_equal "withdrawn", payload["status"]
    assert_not payload["consent"]
    assert_nil payload["featured_position"]
    get "/public/v1/member_stories/#{@record.public_id}", as: :json, headers: website_headers
    assert_response :not_found
    api(:get, "#{member_path}/history")
    events = response.parsed_body["publication_events"]
    assert_equal %w[created draft_saved draft_saved consent_confirmed published featured_order consent_revoked], events.map { |event| event["action"] }
    events.each do |event|
      assert_equal @publisher.id, event["actor_id"]
      assert_equal @token.id, event.dig("details", "delegated_agent", "token_id")
      assert_equal @token.name, event.dig("details", "delegated_agent", "name")
    end
    assert_not_includes response.body, @secret
  end

  test "bearer idempotency replays identical images and rejects changed bytes or request payload" do
    @record = story(publish: false)
    request = { lock_version: @record.lock_version, portrait_base64: Base64.strict_encode64(image_upload.read) }
    key = SecureRandom.uuid
    assert_difference "WebsitePortrait.count", 1 do
      2.times do
        api(:post, "#{member_path}/portrait", request, key: key)
        assert_response :success
      end
    end
    api(:post, "#{member_path}/portrait", request.merge(portrait_base64: Base64.strict_encode64(image_upload(200).read)), key: key)
    assert_response :conflict
    api(:post, "#{member_path}/consent", { lock_version: @record.reload.lock_version, note: "Synthetic consent" }, key: "")
    assert_response :unprocessable_entity
  end

  test "event review source versions and restrictions match admin semantics" do
    source = event_source(title: "Membership meeting picnic", calendar_category: "other")
    api(:post, "", { calendar_event_id: source.id })
    assert_response :created
    @record = WebsitePublication.find(payload["id"])
    api(:post, "", { calendar_event_id: source.id })
    assert_response :conflict
    api(:get, member_path)
    review = { lock_version: payload["lock_version"], source_lock_version: payload.dig("source", "lock_version"), reason: "Human confirmed synthetic public picnic" }
    api(:post, "#{member_path}/eligibility", review)
    assert_response :unprocessable_entity
    api(:post, "#{member_path}/eligibility", review.merge(resolve_flags: true))
    assert_response :success
    assert_equal "public_eligible", payload.dig("source", "website_designation")
    api(:post, "#{member_path}/publish", { lock_version: payload["lock_version"], source_lock_version: review[:source_lock_version] })
    assert_response :conflict
    api(:post, "#{member_path}/publish", { lock_version: @record.reload.lock_version, source_lock_version: source.reload.lock_version })
    assert_response :success
    source.update!(location: "Changed location")
    api(:get, member_path)
    assert payload["pending_source_changes"]
    assert_equal "Changed location", payload.dig("source", "location")
    assert_not_equal "Changed location", payload.dig("snapshot", "location")
    api(:post, "#{member_path}/internal", { lock_version: payload["lock_version"], source_lock_version: payload.dig("source", "lock_version") })
    assert_response :success
    assert_equal "withdrawn", payload["status"]
    assert_equal "internal", source.reload.website_designation
    assert_equal @token.id, @record.publication_events.order(:id).last.details.dig("delegated_agent", "token_id")
  end

  test "private and stored internal events cannot be approved through editorial API" do
    [ { visibility: "members" }, { calendar_category: "honor_guard" } ].each do |attributes|
      source = event_source(**attributes)
      @record = WebsitePublication.create_draft!(organization: @organization, actor: @publisher, calendar_event: source)
      api(:post, "#{member_path}/eligibility", { lock_version: @record.lock_version, source_lock_version: source.lock_version, reason: "Cannot override restriction", resolve_flags: true })
      assert_response :unprocessable_entity
      api(:post, "#{member_path}/publish", { lock_version: @record.reload.lock_version, source_lock_version: source.reload.lock_version })
      assert_response :unprocessable_entity
      assert_not @record.reload.published?
    end
  end

  test "draft and image changes invalidate current consent without replacing approved snapshot" do
    @record = story
    original = @record.snapshot
    version = @record.lock_version
    api(:patch, member_path, { lock_version: version, draft: { introduction: "New draft" } })
    assert_response :success
    assert_not payload["consent_covers_draft"]
    assert_equal original, payload["snapshot"]
    api(:post, "#{member_path}/publish", { lock_version: version })
    assert_response :conflict
    api(:post, "#{member_path}/publish", { lock_version: @record.reload.lock_version })
    assert_response :unprocessable_entity
    api(:post, "#{member_path}/withdraw", { lock_version: @record.lock_version + 1 })
    assert_response :conflict
  end

  test "malformed JSON fields fail with structured 422 without mutations" do
    @record = story
    version = @record.lock_version
    requests = [
      [ :post, "", { calendar_event_id: [] } ],
      [ :post, "", { calendar_event_id: "" } ],
      [ :patch, member_path, { draft: { story: "Missing version" } } ],
      [ :patch, member_path, { lock_version: version.to_s, draft: { story: "String version" } } ],
      [ :patch, member_path, { lock_version: version, draft: [] } ],
      [ :patch, member_path, { lock_version: version, draft: { story: [] } } ],
      [ :patch, member_path, { lock_version: version, draft: { portrait_revision: "forged" } } ],
      [ :post, "#{member_path}/withdraw", { lock_version: version, revoke_consent: "false" } ],
      [ :post, "#{member_path}/portrait", { lock_version: version, portrait_base64: "not base64" } ],
      [ :post, "#{member_path}/portrait", { lock_version: version, portrait_base64: Base64.strict_encode64("not an image") } ],
      [ :post, "#{member_path}/internal", { lock_version: version, source_lock_version: 0 } ],
      [ :put, "/featured", { public_ids: "wrong", versions: {} } ]
    ]
    assert_no_difference "WebsitePublicationEvent.count" do
      requests.each do |method, path, params|
        api(method, path, params)
        assert_response :unprocessable_entity
        assert response.parsed_body["error"].present?
        assert_kind_of Array, response.parsed_body["details"]
      end
    end
    assert_equal version, @record.reload.lock_version
  end

  test "portrait input is bounded before decoding and source review versions are required" do
    @record = story(publish: false)
    assert_no_difference "WebsitePortrait.count" do
      api(:post, "#{member_path}/portrait", { lock_version: @record.lock_version, portrait_base64: "a" * (14.megabytes) })
      assert_response :unprocessable_entity
    end
    source = event_source
    @record = WebsitePublication.create_draft!(organization: @organization, actor: @publisher, calendar_event: source)
    %w[eligibility internal publish].each do |action|
      api(:post, "#{member_path}/#{action}", { lock_version: @record.lock_version, reason: "Synthetic public activity" })
      assert_response :unprocessable_entity
      assert_match(/source_lock_version/, response.parsed_body["error"])
    end
    api(:post, "#{member_path}/portrait", { lock_version: @record.lock_version, portrait_base64: Base64.strict_encode64(image_upload.read) })
    assert_response :unprocessable_entity
    assert_equal "unreviewed", source.reload.website_designation
  end

  test "featured replacement checks complete review and supports empty selection" do
    @record = story
    feature(@record)
    api(:get, "/featured")
    original = response.parsed_body
    story(publish: false)
    api(:put, "/featured", original.merge("public_ids" => []))
    assert_response :conflict
    api(:get, "/featured")
    api(:put, "/featured", response.parsed_body.merge("public_ids" => []))
    assert_response :success
    assert_empty response.parsed_body["public_ids"]
    api(:put, "/featured", response.parsed_body.merge("public_ids" => [ @record.public_id, @record.public_id ]))
    assert_response :unprocessable_entity
  end

  test "publication source and portraits are scoped to this installation" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post")
    foreign = WebsitePublication.create_draft!(organization: other, actor: @publisher)
    api(:get, "/#{foreign.id}")
    assert_response :not_found
    foreign_source = other.calendar_events.create!(title: "Other", starts_at: Time.current, created_by: @publisher, updated_by: @publisher)
    api(:post, "", { calendar_event_id: foreign_source.id })
    assert_response :not_found
    @record = story
    another = story
    api(:get, "#{member_path}/portrait/#{another.draft['portrait_revision']}/small.webp")
    assert_response :not_found
  end

  test "lists and audit paginate including tombstones and reject invalid filters" do
    @record = story
    event = event_publication
    api(:post, "#{member_path}/withdraw", { lock_version: @record.lock_version })
    api(:get, "", { limit: 1 })
    assert_equal 2, response.parsed_body.dig("pagination", "count")
    assert response.parsed_body.dig("pagination", "truncated")
    api(:get, "", { kind: "event", offset: 0 })
    assert_equal [ event.id ], response.parsed_body["website_publications"].map { |entry| entry["id"] }
    api(:get, "", { status: "withdrawn" })
    assert_equal [ @record.id ], response.parsed_body["website_publications"].map { |entry| entry["id"] }
    api(:get, "#{member_path}/history", { limit: 1, offset: 1 })
    assert_equal 1, response.parsed_body.dig("pagination", "returned_count")
    api(:get, "", { kind: "invalid" })
    assert_response :unprocessable_entity
    api(:get, "", { limit: 501 })
    assert_response :unprocessable_entity
    event.calendar_event.destroy!
    api(:get, "/#{event.id}")
    assert_response :success
    assert_nil payload["source"]
    assert payload["original_calendar_event_id"]
  end

  test "revoked permission and disabled token owner cannot replay an editorial mutation" do
    @record = story
    request = { lock_version: @record.lock_version, note: "Synthetic consent" }
    key = SecureRandom.uuid
    api(:post, "#{member_path}/consent", request, key: key)
    assert_response :success
    @publisher.permission_grants.destroy_all
    api(:post, "#{member_path}/consent", request, key: key)
    assert_response :forbidden
    @publisher.update!(disabled_at: Time.current)
    api(:get, member_path)
    assert_response :unauthorized
  end

  test "session writes require current handbook CSRF and have human-only audit" do
    previous = Api::BaseController.allow_forgery_protection
    Api::BaseController.allow_forgery_protection = true
    sign_in_as(@publisher)
    post "/api/website_publications", params: {}, as: :json
    assert_response :unprocessable_entity
    get "/api", as: :json
    csrf = response.parsed_body["csrf_token"]
    post "/api/website_publications", params: {}, headers: { "X-CSRF-Token" => csrf }, as: :json
    assert_response :created
    event = WebsitePublication.find(payload["id"]).publication_events.last
    assert_equal @publisher.id, event.actor_id
    assert_not event.details.key?("delegated_agent")
  ensure
    Api::BaseController.allow_forgery_protection = previous
  end

  test "handbook includes editorial routes fields and workflow only for publishers" do
    [ @manager, @publisher ].each do |user|
      sign_in_as(user)
      get "/api", as: :json
      body = response.parsed_body
      actions = body["common_actions"] + body["only_when_asked"]
      editorial = actions.select { |action| action["path"].start_with?("/api/website_publications") }
      assert_equal user == @publisher ? 14 : 0, editorial.size
      assert_equal user == @publisher, body["website_publishing_fields"].present?
      assert_equal user == @publisher, body["guided_workflows"].any? { |workflow| workflow["name"] == "prepare_website_publication" }
      if user == @publisher
        assert body["only_when_asked"].any? { |action| action["name"] == "publish_website_publication" }
        assert body["only_when_asked"].any? { |action| action["name"] == "confirm_website_publication_consent" }
        get "/api", headers: { "Accept" => "text/markdown" }
        assert_includes response.body, "Website publishing fields"
        assert_includes response.body, "portrait_base64"
        assert_includes response.body, "source_lock_version"
      end
    end
  end

  private

  def bearer
    { "Authorization" => "Bearer #{@secret}" }
  end

  def api(method, suffix, params = {}, key: SecureRandom.uuid)
    public_send(method, "/api/website_publications#{suffix}", params: params, headers: bearer.merge("Idempotency-Key" => key), as: :json)
  end

  def payload
    response.parsed_body.fetch("website_publication")
  end

  def member_path
    "/#{@record.id}"
  end
end
