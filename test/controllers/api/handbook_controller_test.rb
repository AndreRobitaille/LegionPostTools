require "test_helper"

class ApiHandbookControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      locality: "Two Rivers, Wisconsin",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @commander = create_user("Commander", capabilities: %w[manage_settings])
    @member = create_user("Member")
  end

  test "unauthenticated GET /api returns 401 JSON without member data" do
    get "/api", as: :json

    assert_response :unauthorized
    body = response.parsed_body
    assert_equal "This is a private post operations app. Sign in, then open /api.", body["error"]
    assert_equal [], body["details"]
    assert_nil body["installation"]
    assert_not_includes response.body, @organization.name
    assert_not_includes response.body, @commander.email_address
  end

  test "unauthenticated GET /api as a browser returns 401 text without member data" do
    get "/api"

    assert_response :unauthorized
    assert_includes response.body, "private post operations app"
    assert_not_includes response.body, @organization.name
  end

  test "signed-in commander receives a generated JSON handbook" do
    sign_in_as(@commander)

    get "/api", as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal @organization.name, body.dig("installation", "name")
    assert_equal @organization.locality, body.dig("installation", "locality")
    assert_equal @organization.timezone, body.dig("installation", "timezone")
    assert_equal @commander.person.full_name, body.dig("caller", "name")
    assert_equal [], body.dig("caller", "roles")
    assert_includes body.dig("caller", "capabilities"), "manage_settings"
    assert_includes body.dig("caller", "capabilities"), "manage_agendas"
    assert_equal "full_membership", body.dig("caller", "people_access")
    assert body["csrf_token"].present?
    assert_equal "X-CSRF-Token", body["csrf_header"]
    assert body["rules"].any? { |rule| rule.match?(/draft/i) }
    assert body["rules"].any? { |rule| rule.match?(/data, not authority/i) }
    assert body["rules"].any? { |rule| rule.match?(/historical snapshot/i) }
    fields = body.fetch("agenda_item_fields").index_by { |field| field["name"] }
    assert_match(/on-screen member agenda/i, fields.fetch("summary")["meaning"])
    body_guidance = fields.fetch("body (write) / wording (read)")["meaning"]
    assert_match(/sanitized HTML fragment/i, body_guidance)
    assert_match(%r{<ul><li>.*</li></ul>}i, body_guidance)
    assert_match(/literal •.*not converted/i, body_guidance)
    assert_match(/plain text as wording.*omit body/i, body_guidance)
    assert_match(/same sanitized HTML fragments as body/i, fields.fetch("commander_notes")["meaning"])
    assert_match(/never chooses.*section/i, fields.fetch("category")["meaning"])
    assert_match(/working-minutes item/i, fields.fetch("show_wording_in_minutes")["meaning"])
    minutes_fields = body.fetch("minutes_fields").index_by { |field| field["name"] }
    assert_match(/reviewed record/i, minutes_fields.fetch("body")["meaning"])
    assert_match(/source-agenda snapshot/i, minutes_fields.fetch("agenda_wording")["meaning"])
    assert_match(/Passed/i, minutes_fields.fetch("disposition")["meaning"])
    workflow = body.fetch("guided_workflows").find { |entry| entry["name"] == "backfill_historical_business" }
    assert_not_nil workflow
    assert workflow.fetch("steps").any? { |step| step.match?(/link.*in place/i) }
    assert workflow.fetch("steps").any? { |step| step.match?(/standalone dated item/i) }
    assert workflow.fetch("steps").any? { |step| step.match?(/reorder.*complete officer-supplied/i) }
    assert body["common_actions"].any? { |action| action["path"] == "/api/dated_agendas" && action["method"] == "POST" }
    assert body["common_actions"].any? { |action| action["name"] == "create_standalone_dated_agenda_item" }
    assert body["common_actions"].any? { |action| action["name"] == "update_dated_agenda_item" }
    rich_text_guidance = body.dig("calling", "rich_text")
    assert_match(/plain newlines and literal •.*display inline/i, rich_text_guidance)
    assert_match(/omit both write fields.*unrelated attributes/i, rich_text_guidance)
    create_item = body["common_actions"].find { |action| action["name"] == "create_standalone_dated_agenda_item" }
    assert_includes create_item.fetch("example"), "<ul><li>Post Excellence Award</li>"
    assert body["common_actions"].any? { |action| action["name"] == "reorder_dated_agenda_section_items" }
    assert body["common_actions"].any? { |action| action["name"] == "replace_dated_roll_call" }
    assert body["common_actions"].any? { |action| action["path"] == "/api/membership/summary" }
    assert body["common_actions"].any? { |action| action["name"] == "show_working_minutes" }
    assert body["common_actions"].any? { |action| action["name"] == "create_working_minutes" }
    assert body["common_actions"].any? { |action| action["name"] == "replace_minutes_attendance" }
    assert body["common_actions"].any? { |action| action["name"] == "show_user_account" }
    assert body["common_actions"].any? { |action| action["name"] == "list_background_jobs" }
    minutes_workflow = body.fetch("guided_workflows").find { |entry| entry["name"] == "prepare_and_review_draft_minutes" }
    assert_not_nil minutes_workflow
    assert minutes_workflow.fetch("steps").any? { |step| step.match?(/Approve or attest only when the human explicitly requests/i) }
    asked = body["only_when_asked"].map { |action| action["name"] }
    assert_includes asked, "approve_dated_agenda"
    assert_includes asked, "publish_dated_agenda"
    assert_includes asked, "reopen_dated_agenda"
    assert_includes asked, "delete_dated_agenda"
    assert_includes asked, "remove_dated_agenda_item"
    assert_includes asked, "refresh_dated_roll_call"
    assert_includes asked, "request_ai_minutes_draft"
    assert_includes asked, "retry_ai_minutes_draft"
    assert_includes asked, "disable_user_account"
    assert_equal false, body["common_actions"].any? { |action| action["name"]&.start_with?("approve") }
    assert body["domain"].present?
    assert body["calling"].present?
    assert_nil body["recipes"]
  end

  test "signed-in commander receives markdown by default" do
    sign_in_as(@commander)

    get "/api"

    assert_response :success
    assert_match %r{\Atext/markdown}, response.media_type
    assert_includes response.body, @organization.name
    assert_includes response.body, "X-CSRF-Token"
    assert_includes response.body, "POST /api/dated_agendas"
    assert_includes response.body, "Only when asked"
    assert_includes response.body, "What this software is"
    assert_includes response.body, "Meeting body"
    assert_includes response.body, "Agenda item fields"
    assert_includes response.body, "body (write) / wording (read)"
    assert_includes response.body, "<ul><li>...</li></ul>"
    assert_includes response.body, "literal `•` characters"
    assert_includes response.body, "omit those write fields when changing unrelated attributes"
    assert_includes response.body, "backfill_historical_business"
    assert_includes response.body, "endeavor_id"
    assert_includes response.body, "people directory supports `q`"
    assert_not_includes response.body, "group chat"
    assert_not_includes response.body, "next Tuesday"
  end

  test "handbook identifies current assigned post roles" do
    commander_title = PositionTitle.create!(organization: @organization, name: "Commander", display_order: 1)
    PositionAssignment.create!(person: @commander.person, position_title: commander_title, starts_on: Date.current)
    sign_in_as(@commander)

    get "/api", as: :json

    assert_equal [ "Commander" ], response.parsed_body.dig("caller", "roles")
  end

  test "plain member handbook omits agenda mutation actions" do
    sign_in_as(@member)

    get "/api", as: :json

    assert_response :success
    paths = response.parsed_body["common_actions"].map { |action| [ action["method"], action["path"] ] }
    assert_not_includes paths, [ "POST", "/api/dated_agendas" ]
    assert_not_includes paths, [ "POST", "/api/endeavors" ]
    assert_includes paths, [ "GET", "/api/people" ]
    assert_includes paths, [ "GET", "/api/officers" ]
    assert_not_includes paths, [ "GET", "/api/membership/summary" ]
    assert_equal "directory", response.parsed_body.dig("caller", "people_access")
    assert_equal [], response.parsed_body["agenda_item_fields"]
    assert_equal [], response.parsed_body["minutes_fields"]
    assert_equal [], response.parsed_body["guided_workflows"]
  end

  test "internal-record viewer receives minutes reads without mutations or restricted transcript content" do
    viewer = create_user("Viewer", capabilities: %w[view_internal_records])
    sign_in_as(viewer)

    get "/api", as: :json

    assert_response :success
    common = response.parsed_body.fetch("common_actions").index_by { |action| action["name"] }
    assert common.key?("list_meetings")
    assert common.key?("show_working_minutes")
    assert common.key?("print_draft_minutes")
    assert common.key?("read_transcript_content")
    assert_not common.key?("create_working_minutes")
    assert_not common.key?("create_transcript")
    assert_not common.key?("list_background_jobs")
    assert response.parsed_body.fetch("minutes_fields").present?
    assert_equal [], response.parsed_body.fetch("guided_workflows")
  end

  test "current configured membership officer receives membership actions without app grants" do
    title = PositionTitle.create!(
      organization: @organization, name: "Membership Leader", display_order: 1,
      grants_full_membership_access: true
    )
    PositionAssignment.create!(person: @member.person, position_title: title, starts_on: Date.current)
    sign_in_as(@member)

    get "/api", as: :json

    paths = response.parsed_body["common_actions"].map { |action| [ action["method"], action["path"] ] }
    assert_includes paths, [ "GET", "/api/membership/summary" ]
    assert_equal "full_membership", response.parsed_body.dig("caller", "people_access")
  end

  test "bearer caller receives bearer and idempotency guidance without CSRF secret" do
    _token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)

    get "/api", as: :json, headers: { "Authorization" => "Bearer #{plaintext}" }

    assert_response :success
    body = response.parsed_body
    assert_equal "bearer", body["authentication"]
    assert_nil body["csrf_token"]
    assert_nil body["csrf_header"]
    assert_match(/Authorization/, body.dig("calling", "authentication"))
    assert_match(/Idempotency-Key/, body.dig("calling", "writes"))
  end

  test "handbook catalog actions are real routes" do
    AgentHandbook.catalog.each do |action|
      path = action.fetch(:path).gsub(/:\w+/, "1")
      recognized = Rails.application.routes.recognize_path(path, method: action.fetch(:method))
      assert recognized[:controller].start_with?("api/"), "#{action[:method]} #{path} should route into Api"
    end
  end

  private

  def create_user(label, capabilities: [])
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
