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
    assert_includes body.dig("caller", "capabilities"), "manage_settings"
    assert_includes body.dig("caller", "capabilities"), "manage_agendas"
    assert body["csrf_token"].present?
    assert_equal "X-CSRF-Token", body["csrf_header"]
    assert body["rules"].any? { |rule| rule.match?(/draft/i) }
    assert body["common_actions"].any? { |action| action["path"] == "/api/dated_agendas" && action["method"] == "POST" }
    asked = body["only_when_asked"].map { |action| action["name"] }
    assert_includes asked, "approve_dated_agenda"
    assert_includes asked, "publish_dated_agenda"
    assert_includes asked, "reopen_dated_agenda"
    assert_equal false, body["common_actions"].any? { |action| action["name"]&.start_with?("approve") }
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
  end

  test "plain member handbook omits agenda mutation actions" do
    sign_in_as(@member)

    get "/api", as: :json

    assert_response :success
    paths = response.parsed_body["common_actions"].map { |action| [ action["method"], action["path"] ] }
    assert_not_includes paths, [ "POST", "/api/dated_agendas" ]
    assert_not_includes paths, [ "POST", "/api/tracked_items" ]
  end

  test "handbook catalog actions are real routes" do
    AgentHandbook.catalog.each do |action|
      path = action.fetch(:path).gsub(":id", "1")
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
