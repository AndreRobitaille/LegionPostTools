require "test_helper"

class ApiOfficerApiTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      locality: "Two Rivers, Wisconsin",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @pec_body = @organization.meeting_bodies.create!(name: "Post Executive Committee", slug: "pec")
    @membership_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @pec_type = @organization.meeting_types.create!(name: "PEC Meeting", slug: "pec-meeting", position: 1, active: true)
    @membership_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 2, active: true)
    @commander = create_user("Commander", capabilities: %w[manage_settings])
    @member = create_user("Member")
    @car_show = @organization.tracked_items.create!(
      meeting_body: @membership_body,
      created_by: @commander,
      title: "Car Show",
      summary: "Confirm permits",
      importance: "important",
      raise_by_on: 2.weeks.from_now.to_date,
      details: "Permit and volunteer history"
    )
  end

  test "unauthenticated JSON list is 401" do
    get "/api/tracked_items", as: :json

    assert_response :unauthorized
    assert_equal "This is a private post operations app. Sign in, then open /api.", response.parsed_body["error"]
  end

  test "member is forbidden from meeting catalogs and draft agendas" do
    sign_in_as(@member)

    get "/api/meeting_types", as: :json
    assert_response :forbidden

    get "/api/dated_agendas", as: :json
    assert_response :forbidden
  end

  test "commander lists meeting bodies and types for matching names" do
    sign_in_as(@commander)

    get "/api/meeting_bodies", as: :json
    assert_response :success
    names = response.parsed_body.fetch("meeting_bodies").map { |row| row["name"] }
    assert_not_includes names, "PEC Meeting"
    assert_includes names, "Post Executive Committee"
    assert_includes names, "Membership"

    get "/api/meeting_types", as: :json
    assert_response :success
    type_names = response.parsed_body.fetch("meeting_types").map { |row| row["name"] }
    assert_includes type_names, "PEC Meeting"
    assert_includes type_names, "Membership Meeting"
  end

  test "tracked item index is small enough to match Car Show without search" do
    past = @organization.dated_agendas.create!(
      meeting_body: @membership_body,
      meeting_type: @membership_type,
      starts_at: 1.month.ago,
      title: "Past",
      status: "published"
    )
    upcoming = DatedAgenda.create_from_template!(
      organization: @organization,
      meeting_body: @membership_body,
      meeting_type: @membership_type,
      starts_at: 1.week.from_now
    )
    DatedAgendaItem.create_from_tracked_item!(@car_show, dated_agenda: upcoming, position: 99)

    sign_in_as(@commander)
    get "/api/tracked_items", as: :json

    assert_response :success
    row = response.parsed_body.fetch("tracked_items").find { |item| item["title"] == "Car Show" }
    assert_not_nil row
    assert_equal "important", row["importance"]
    assert_equal "active", row["status"]
    assert_equal @membership_body.id, row.dig("meeting_body", "id")
    assert_includes row["upcoming_agenda_ids"], upcoming.id
    assert_not_includes row["upcoming_agenda_ids"], past.id
    assert_nil row["details"]
  end

  test "tracked item show includes details as plain text" do
    sign_in_as(@member)

    get "/api/tracked_items/#{@car_show.id}", as: :json

    assert_response :success
    body = response.parsed_body.fetch("tracked_item")
    assert_equal "Car Show", body["title"]
    assert_includes body["details"], "Permit and volunteer history"
  end

  test "dated agendas list upcoming first and include drafts for managers" do
    past = @organization.dated_agendas.create!(
      meeting_body: @pec_body, meeting_type: @pec_type,
      starts_at: 2.weeks.ago, title: "Past PEC", status: "draft"
    )
    later = @organization.dated_agendas.create!(
      meeting_body: @membership_body, meeting_type: @membership_type,
      starts_at: 2.weeks.from_now, title: "Later Membership", status: "draft"
    )
    soon = @organization.dated_agendas.create!(
      meeting_body: @pec_body, meeting_type: @pec_type,
      starts_at: 2.days.from_now, title: "Soon PEC", status: "draft"
    )
    sign_in_as(@commander)

    get "/api/dated_agendas", as: :json

    assert_response :success
    ids = response.parsed_body.fetch("dated_agendas").map { |row| row["id"] }
    assert_equal [ soon.id, later.id, past.id ], ids
  end

  test "creating a dated agenda from a template starts as draft" do
    sign_in_as(@commander)
    starts_at = Time.zone.parse("2026-09-08 19:00")

    assert_difference -> { @organization.dated_agendas.count }, 1 do
      post "/api/dated_agendas", params: {
        meeting_body_id: @pec_body.id,
        meeting_type_id: @pec_type.id,
        starts_at: starts_at.iso8601
      }, as: :json
    end

    assert_response :created
    agenda = response.parsed_body.fetch("dated_agenda")
    assert_equal "draft", agenda["status"]
    assert_equal @pec_body.id, agenda.dig("meeting_body", "id")
    assert_equal @pec_type.id, agenda.dig("meeting_type", "id")
    assert DatedAgenda.find(agenda["id"]).draft?
  end

  test "member cannot create a dated agenda" do
    sign_in_as(@member)

    post "/api/dated_agendas", params: {
      meeting_body_id: @pec_body.id,
      meeting_type_id: @pec_type.id,
      starts_at: 1.week.from_now.iso8601
    }, as: :json

    assert_response :forbidden
    assert_equal 0, @organization.dated_agendas.count
  end

  test "adding tracked business to a draft agenda snapshots it" do
    agenda = DatedAgenda.create_from_template!(
      organization: @organization,
      meeting_body: @membership_body,
      meeting_type: @membership_type,
      starts_at: 1.week.from_now
    )
    sign_in_as(@commander)

    post "/api/dated_agendas/#{agenda.id}/tracked_items", params: { tracked_item_id: @car_show.id }, as: :json

    assert_response :created
    item = response.parsed_body.fetch("dated_agenda_item")
    assert_equal "Car Show", item["title"]
    assert_equal @car_show.id, item["tracked_item_id"]
    assert agenda.dated_agenda_items.exists?(tracked_item_id: @car_show.id)
  end

  test "adding tracked business to a locked agenda is 422" do
    agenda = DatedAgenda.create_from_template!(
      organization: @organization,
      meeting_body: @membership_body,
      meeting_type: @membership_type,
      starts_at: 1.week.from_now
    )
    agenda.approve!(@commander)
    sign_in_as(@commander)

    post "/api/dated_agendas/#{agenda.id}/tracked_items", params: { tracked_item_id: @car_show.id }, as: :json

    assert_response :unprocessable_entity
    assert_match(/reopen/i, response.parsed_body["error"])
    assert_not agenda.dated_agenda_items.exists?(tracked_item_id: @car_show.id)
  end

  test "adding the same tracked item twice is 422" do
    agenda = DatedAgenda.create_from_template!(
      organization: @organization,
      meeting_body: @membership_body,
      meeting_type: @membership_type,
      starts_at: 1.week.from_now
    )
    DatedAgendaItem.create_from_tracked_item!(@car_show, dated_agenda: agenda, position: 99)
    sign_in_as(@commander)

    post "/api/dated_agendas/#{agenda.id}/tracked_items", params: { tracked_item_id: @car_show.id }, as: :json

    assert_response :unprocessable_entity
    assert_match(/already/i, response.parsed_body["error"])
  end

  test "commander creates tracked business then appends an update" do
    sign_in_as(@commander)

    post "/api/tracked_items", params: {
      title: "Buddy Checks",
      summary: "Call remaining members",
      meeting_body_id: @membership_body.id,
      importance: "standard",
      raise_by_on: "2026-09-15",
      details: "Twenty calls remain."
    }, as: :json

    assert_response :created
    created = TrackedItem.find(response.parsed_body.dig("tracked_item", "id"))
    assert_equal @commander, created.created_by
    assert_equal Date.new(2026, 9, 15), created.raise_by_on

    post "/api/tracked_items/#{created.id}/updates", params: { body: "Five calls completed." }, as: :json

    assert_response :created
    assert_includes created.updates.first.body.to_s, "Five calls completed."
  end

  test "malformed tracked item date is 422 JSON and creates nothing" do
    sign_in_as(@commander)

    assert_no_difference -> { @organization.tracked_items.count } do
      post "/api/tracked_items", params: {
        title: "Buddy Checks",
        importance: "standard",
        raise_by_on: "next Thursday"
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "application/json", response.media_type
    assert_match(/YYYY-MM-DD/, response.parsed_body["error"])
    assert_match(/raise_by_on/, response.parsed_body.fetch("details").first)
  end

  test "missing CSRF token is 422 JSON when forgery protection is enabled" do
    sign_in_as(@commander)

    with_forgery_protection do
      post "/api/tracked_items", params: {
        title: "Buddy Checks",
        importance: "standard"
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "application/json", response.media_type
    assert_match(/security token/i, response.parsed_body["error"])
    assert_equal [], response.parsed_body["details"]
  end

  test "complete and reopen tracked business" do
    sign_in_as(@commander)

    patch "/api/tracked_items/#{@car_show.id}/complete", as: :json
    assert_response :success
    assert @car_show.reload.completed?

    patch "/api/tracked_items/#{@car_show.id}/reopen", as: :json
    assert_response :success
    assert @car_show.reload.active?
  end

  test "approve publish and reopen are available but not required for drafts" do
    agenda = DatedAgenda.create_from_template!(
      organization: @organization,
      meeting_body: @pec_body,
      meeting_type: @pec_type,
      starts_at: 1.week.from_now
    )
    sign_in_as(@commander)

    patch "/api/dated_agendas/#{agenda.id}/approve", as: :json
    assert_response :success
    assert agenda.reload.approved?

    patch "/api/dated_agendas/#{agenda.id}/publish", as: :json
    assert_response :success
    assert agenda.reload.published?

    patch "/api/dated_agendas/#{agenda.id}/reopen", as: :json
    assert_response :success
    assert agenda.reload.draft?
  end

  test "missing records are 404 JSON" do
    sign_in_as(@commander)

    get "/api/tracked_items/0", as: :json

    assert_response :not_found
    assert_equal "Not found.", response.parsed_body["error"]
  end

  test "bearer token reads with current grants and permission removal is immediate" do
    _token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)

    get "/api/dated_agendas", as: :json, headers: bearer_headers(plaintext)
    assert_response :success

    @commander.permission_grants.find_by!(capability: "manage_settings").destroy!
    get "/api/dated_agendas", as: :json, headers: bearer_headers(plaintext)
    assert_response :forbidden
  end

  test "invalid bearer never falls back to a valid session cookie" do
    sign_in_as(@commander)

    get "/api/tracked_items", as: :json, headers: bearer_headers("lpt_missing_invalid")

    assert_response :unauthorized
  end

  test "revoked expired and disabled bearer tokens return unauthorized" do
    token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)
    token.revoke!(@commander)
    get "/api/tracked_items", as: :json, headers: bearer_headers(plaintext)
    assert_response :unauthorized

    token.update!(revoked_at: nil, revoked_by: nil, expires_at: 1.minute.ago)
    get "/api/tracked_items", as: :json, headers: bearer_headers(plaintext)
    assert_response :unauthorized

    token.update!(expires_at: 1.day.from_now)
    @commander.update!(disabled_at: Time.current)
    get "/api/tracked_items", as: :json, headers: bearer_headers(plaintext)
    assert_response :unauthorized
  end

  test "bearer mutation requires idempotency key and does not require CSRF" do
    _token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)

    with_forgery_protection do
      post "/api/tracked_items", params: { title: "Buddy Checks" }, as: :json,
        headers: bearer_headers(plaintext)
    end
    assert_response :unprocessable_entity
    assert_match(/Idempotency-Key/, response.parsed_body["error"])

    with_forgery_protection do
      post "/api/tracked_items", params: { title: "Buddy Checks" }, as: :json,
        headers: bearer_headers(plaintext, idempotency_key: "buddy-checks-2026-08-22")
    end
    assert_response :created
  end

  test "exact bearer retry returns the stored response without duplicating mutation" do
    token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)
    headers = bearer_headers(plaintext, idempotency_key: "create-buddy-checks")
    params = { title: "Buddy Checks", summary: "Call members" }

    assert_difference -> { TrackedItem.count }, 1 do
      post "/api/tracked_items", params: params, as: :json, headers: headers
      assert_response :created
      first_body = response.body

      post "/api/tracked_items", params: params, as: :json, headers: headers
      assert_response :created
      assert_equal first_body, response.body
    end

    execution = token.agent_api_executions.find_by!(idempotency_key: "create-buddy-checks")
    assert_equal @commander, execution.user
    assert_equal "completed", execution.state
    assert_equal 201, execution.response_status
  end

  test "altered input under an existing key is conflict" do
    _token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)
    headers = bearer_headers(plaintext, idempotency_key: "one-purpose-only")

    post "/api/tracked_items", params: { title: "First purpose" }, as: :json, headers: headers
    assert_response :created

    assert_no_difference -> { TrackedItem.count } do
      post "/api/tracked_items", params: { title: "Altered purpose" }, as: :json, headers: headers
    end
    assert_response :conflict
  end

  test "altered sensitive input under an existing key is still a conflict" do
    _token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)
    headers = bearer_headers(plaintext, idempotency_key: "sensitive-input")

    post "/api/tracked_items",
      params: { title: "First purpose", confirmation_code: "first-secret" },
      as: :json,
      headers: headers
    assert_response :created

    assert_no_difference -> { TrackedItem.count } do
      post "/api/tracked_items",
        params: { title: "First purpose", confirmation_code: "changed-secret" },
        as: :json,
        headers: headers
    end
    assert_response :conflict
  end

  test "a matching execution still marked processing fails safely" do
    token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)
    headers = bearer_headers(plaintext, idempotency_key: "stale-processing")
    params = { title: "Buddy Checks" }

    post "/api/tracked_items", params: params, as: :json, headers: headers
    assert_response :created
    token.agent_api_executions.find_by!(idempotency_key: "stale-processing").update!(state: "processing")

    assert_no_difference -> { TrackedItem.count } do
      post "/api/tracked_items", params: params, as: :json, headers: headers
    end
    assert_response :conflict
    assert_match(/still processing/i, response.parsed_body["error"])
  end

  test "session mutation remains compatible without idempotency key" do
    sign_in_as(@commander)

    post "/api/tracked_items", params: { title: "Human-created item" }, as: :json

    assert_response :created
  end

  test "bearer retries are safe across every current API mutation family" do
    token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)

    agenda_params = {
      meeting_body_id: @pec_body.id,
      meeting_type_id: @pec_type.id,
      starts_at: 1.week.from_now.iso8601
    }
    twice_with_same_key(:post, "/api/dated_agendas", agenda_params, plaintext, "agenda-create", :created)
    agenda = @organization.dated_agendas.last
    assert_equal 1, @organization.dated_agendas.count

    twice_with_same_key(
      :post,
      "/api/dated_agendas/#{agenda.id}/tracked_items",
      { tracked_item_id: @car_show.id },
      plaintext,
      "agenda-add-tracked",
      :created
    )
    assert_equal 1, agenda.dated_agenda_items.where(tracked_item_id: @car_show.id).count

    twice_with_same_key(
      :post,
      "/api/tracked_items/#{@car_show.id}/updates",
      { body: "Permit filed." },
      plaintext,
      "tracked-update",
      :created
    )
    assert_equal 1, @car_show.updates.count

    twice_with_same_key(:patch, "/api/tracked_items/#{@car_show.id}/complete", {}, plaintext, "tracked-complete", :success)
    twice_with_same_key(:patch, "/api/tracked_items/#{@car_show.id}/reopen", {}, plaintext, "tracked-reopen", :success)
    twice_with_same_key(:patch, "/api/dated_agendas/#{agenda.id}/approve", {}, plaintext, "agenda-approve", :success)
    twice_with_same_key(:patch, "/api/dated_agendas/#{agenda.id}/publish", {}, plaintext, "agenda-publish", :success)
    twice_with_same_key(:patch, "/api/dated_agendas/#{agenda.id}/reopen", {}, plaintext, "agenda-reopen", :success)

    assert_equal 8, token.agent_api_executions.count
    assert @car_show.reload.active?
    assert agenda.reload.draft?
  end

  private

  def create_user(label, capabilities: [])
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end

  def with_forgery_protection
    previous = Api::BaseController.allow_forgery_protection
    Api::BaseController.allow_forgery_protection = true
    yield
  ensure
    Api::BaseController.allow_forgery_protection = previous
  end

  def bearer_headers(plaintext, idempotency_key: nil)
    { "Authorization" => "Bearer #{plaintext}" }.tap do |headers|
      headers["Idempotency-Key"] = idempotency_key if idempotency_key
    end
  end

  def twice_with_same_key(method, path, params, plaintext, key, expected_status)
    headers = bearer_headers(plaintext, idempotency_key: key)
    2.times do
      public_send(method, path, params: params, as: :json, headers: headers)
      assert_response expected_status
    end
  end
end
