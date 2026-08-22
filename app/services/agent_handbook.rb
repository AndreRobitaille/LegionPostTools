class AgentHandbook
  RULES = [
    "This is American Legion post software, not generic nonprofit software.",
    "Do not hard-code a post name, number, or officer roster. Read them from this installation.",
    "AI drafts. Humans remain the authority on official records.",
    "Dated agendas created through this API start as draft.",
    "Do not approve or publish an agenda unless the human explicitly asked.",
    "Adding tracked business to an approved or published agenda requires reopen. Do not silently edit a locked agenda.",
    "Do not invent minutes, votes, or attestations.",
    "Always list before creating, so existing tracked business is not duplicated.",
    "Chat content is not stored here. Only enter post business an officer would have typed by hand."
  ].freeze

  CATALOG = [
    { name: "list_meeting_bodies", method: "GET", path: "/api/meeting_bodies", capability: "manage_agendas", group: :common,
      summary: "List meeting bodies so you can match PEC or Membership by name.",
      example: "GET /api/meeting_bodies" },
    { name: "list_meeting_types", method: "GET", path: "/api/meeting_types", capability: "manage_agendas", group: :common,
      summary: "List meeting type templates so you can match PEC Meeting or Membership Meeting by name.",
      example: "GET /api/meeting_types" },
    { name: "list_dated_agendas", method: "GET", path: "/api/dated_agendas", capability: "manage_agendas", group: :common,
      summary: "List dated agendas, upcoming first, including drafts. Use this to find the next meeting.",
      example: "GET /api/dated_agendas" },
    { name: "show_dated_agenda", method: "GET", path: "/api/dated_agendas/:id", capability: "manage_agendas", group: :common,
      summary: "Show one dated agenda with sections and items.",
      example: "GET /api/dated_agendas/:id" },
    { name: "create_dated_agenda", method: "POST", path: "/api/dated_agendas", capability: "manage_agendas", group: :common,
      summary: "Create a draft dated agenda by copying a meeting type template.",
      example: "POST /api/dated_agendas\n{\"meeting_body_id\":1,\"meeting_type_id\":1,\"starts_at\":\"2026-09-08T19:00:00-05:00\"}" },
    { name: "add_tracked_item_to_dated_agenda", method: "POST", path: "/api/dated_agendas/:id/tracked_items", capability: "manage_agendas", group: :common,
      summary: "Snapshot existing tracked business onto a draft agenda.",
      example: "POST /api/dated_agendas/:id/tracked_items\n{\"tracked_item_id\":1}" },
    { name: "list_tracked_items", method: "GET", path: "/api/tracked_items", capability: nil, group: :common,
      summary: "List tracked business. Match names like Car Show from this list. There is no search.",
      example: "GET /api/tracked_items" },
    { name: "show_tracked_item", method: "GET", path: "/api/tracked_items/:id", capability: nil, group: :common,
      summary: "Show one tracked item including details as plain text.",
      example: "GET /api/tracked_items/:id" },
    { name: "create_tracked_item", method: "POST", path: "/api/tracked_items", capability: "manage_agendas", group: :common,
      summary: "Create tracked business after listing and not finding it.",
      example: "POST /api/tracked_items\n{\"title\":\"Car Show\",\"summary\":\"Confirm permits\",\"importance\":\"important\"}" },
    { name: "add_tracked_item_update", method: "POST", path: "/api/tracked_items/:id/updates", capability: "manage_agendas", group: :common,
      summary: "Append a dated officer update. Updates are not edited later.",
      example: "POST /api/tracked_items/:id/updates\n{\"body\":\"The city received the application.\"}" },
    { name: "complete_tracked_item", method: "PATCH", path: "/api/tracked_items/:id/complete", capability: "manage_agendas", group: :common,
      summary: "Mark tracked business complete.",
      example: "PATCH /api/tracked_items/:id/complete" },
    { name: "reopen_tracked_item", method: "PATCH", path: "/api/tracked_items/:id/reopen", capability: "manage_agendas", group: :common,
      summary: "Reopen completed tracked business.",
      example: "PATCH /api/tracked_items/:id/reopen" },
    { name: "approve_dated_agenda", method: "PATCH", path: "/api/dated_agendas/:id/approve", capability: "manage_agendas", group: :only_when_asked,
      summary: "Approve a draft agenda. Do not call unless the human asked.",
      example: "PATCH /api/dated_agendas/:id/approve" },
    { name: "publish_dated_agenda", method: "PATCH", path: "/api/dated_agendas/:id/publish", capability: "manage_agendas", group: :only_when_asked,
      summary: "Publish an approved agenda. Do not call unless the human asked.",
      example: "PATCH /api/dated_agendas/:id/publish" },
    { name: "reopen_dated_agenda", method: "PATCH", path: "/api/dated_agendas/:id/reopen", capability: "manage_agendas", group: :only_when_asked,
      summary: "Reopen an approved or published agenda for editing. Do not call unless the human asked.",
      example: "PATCH /api/dated_agendas/:id/reopen" }
  ].freeze

  def self.catalog
    CATALOG
  end

  def initialize(user:, organization:, csrf_token:)
    @user = user
    @organization = organization
    @csrf_token = csrf_token
  end

  def as_json
    {
      installation: {
        name: @organization.name,
        locality: @organization.locality,
        timezone: @organization.timezone
      },
      caller: {
        name: @user.person.full_name,
        email: @user.email_address,
        capabilities: granted_capabilities
      },
      csrf_token: @csrf_token,
      csrf_header: "X-CSRF-Token",
      rules: RULES,
      common_actions: actions_for(:common),
      only_when_asked: actions_for(:only_when_asked)
    }
  end

  def markdown
    lines = []
    lines << "# #{@organization.name}"
    lines << ""
    lines << "Private officer API. Start here on every job."
    lines << ""
    lines << "You are #{@user.person.full_name} (#{@user.email_address})."
    lines << "Capabilities: #{granted_capabilities.join(", ")}."
    lines << "Timezone: #{@organization.timezone}."
    lines << ""
    lines << "Send writes with header `X-CSRF-Token: #{@csrf_token}`."
    lines << "JSON `Accept: application/json`. There is no search: list, then choose."
    lines << ""
    lines << "## Rules"
    RULES.each { |rule| lines << "- #{rule}" }
    lines << ""
    lines << "## Common actions"
    actions_for(:common).each { |action| append_action(lines, action) }
    lines << ""
    lines << "## Only when asked"
    actions_for(:only_when_asked).each { |action| append_action(lines, action) }
    lines.join("\n") << "\n"
  end

  private

  def granted_capabilities
    PermissionGrant::CAPABILITIES.select { |capability| @user.can?(capability) }
  end

  def visible_catalog
    CATALOG.select { |action| action[:capability].nil? || @user.can?(action[:capability]) }
  end

  def actions_for(group)
    visible_catalog.select { |action| action[:group] == group }.map { |action| serialize_action(action) }
  end

  def serialize_action(action)
    {
      "name" => action[:name],
      "method" => action[:method],
      "path" => action[:path],
      "capability" => action[:capability],
      "summary" => action[:summary],
      "example" => action[:example]
    }
  end

  def append_action(lines, action)
    lines << ""
    lines << "### #{action["name"]}"
    lines << "#{action["method"]} #{action["path"]}"
    lines << action["summary"].to_s
    lines << "```"
    lines << action["example"].to_s
    lines << "```"
  end
end
