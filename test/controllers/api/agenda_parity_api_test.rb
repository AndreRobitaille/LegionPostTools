require "test_helper"

class ApiAgendaParityApiTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      locality: "Two Rivers, Wisconsin",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    @commander = create_user("Commander", capabilities: %w[manage_settings])
    @member = create_user("Member")
    @tracker = @organization.tracked_items.create!(
      meeting_body: @meeting_body,
      created_by: @commander,
      title: "Buddy Checks",
      summary: "Call members",
      importance: "standard",
      details: "Monthly outreach"
    )
  end

  test "catalog API lists reorders and soft-removes kept entries" do
    opening = catalog_entry("Call to Order", "opening_ceremony", 1)
    minutes = catalog_entry("Minutes", "call_to_order", 1)
    report = catalog_entry("Buddy Checks Report", "reports", 1)
    sign_in_as(@commander)

    get "/api/agenda_item_catalog_entries", as: :json
    assert_response :success
    assert_equal [ opening.id, minutes.id, report.id ], response.parsed_body.fetch("agenda_item_catalog_entries").map { |entry| entry["id"] }

    categories = AgendaItemCatalogEntry::CATEGORIES.keys.index_with { [] }
    categories["reports"] = [ report.id, opening.id, minutes.id ]
    post "/api/agenda_item_catalog_entries/reorder", params: { categories: categories }, as: :json
    assert_response :success
    assert_equal [ report.id, opening.id, minutes.id ], @organization.agenda_item_catalog_entries.kept.order(:position).pluck(:id)
    assert_equal [ "reports", "reports", "reports" ], @organization.agenda_item_catalog_entries.kept.order(:position).pluck(:category)

    delete "/api/agenda_item_catalog_entries/#{opening.id}", as: :json
    assert_response :success
    assert opening.reload.removed_from_catalog_at.present?
    assert @organization.agenda_item_catalog_entries.exists?(opening.id)
    assert_not @organization.agenda_item_catalog_entries.kept.exists?(opening.id)
  end

  test "catalog API creates and edits reusable document controls" do
    sign_in_as(@commander)

    post "/api/agenda_item_catalog_entries", params: {
      title: "Service Project",
      summary: "Review open work",
      category: "unfinished_business",
      behavior_type: "business_item",
      active: true,
      body: "Member-facing wording",
      commander_notes: "Ask for a status owner.",
      show_wording_on_agenda: true,
      show_wording_in_minutes: false
    }, as: :json

    assert_response :created
    entry = AgendaItemCatalogEntry.find(response.parsed_body.dig("agenda_item_catalog_entry", "id"))
    assert_equal "Member-facing wording", entry.body.to_plain_text
    assert_equal "Ask for a status owner.", entry.commander_notes.to_plain_text
    assert_not entry.show_wording_in_minutes

    patch "/api/agenda_item_catalog_entries/#{entry.id}", params: {
      category: "new_business",
      summary: "Request a decision"
    }, as: :json

    assert_response :success
    assert_equal "new_business", entry.reload.category
    assert_equal "Request a decision", entry.summary
  end

  test "plain member cannot manage the agenda catalog" do
    sign_in_as(@member)

    get "/api/agenda_item_catalog_entries", as: :json

    assert_response :forbidden
  end

  test "dated item API links standalone historical business to a tracker in place" do
    agenda, unfinished, = historical_agenda
    item = agenda.dated_agenda_items.create!(
      agenda_section: unfinished,
      position: 1,
      title: "Buddy Checks",
      summary: "Submit the monthly count",
      behavior_type: "business_item",
      body: "Call members who may need help.",
      active: true
    )
    original_count = agenda.dated_agenda_items.count
    original_position = item.position
    original_wording = item.body.to_plain_text
    sign_in_as(@commander)

    patch "/api/dated_agendas/#{agenda.id}/items/#{item.id}", params: {
      tracked_item_id: @tracker.id,
      lock_version: item.lock_version
    }, as: :json

    assert_response :success
    item.reload
    assert_equal original_count, agenda.dated_agenda_items.count
    assert_equal @tracker, item.tracked_item
    assert_equal unfinished, item.agenda_section
    assert_equal original_position, item.position
    assert_equal original_wording, item.body.to_plain_text
    assert_equal @tracker.id, response.parsed_body.dig("dated_agenda_item", "tracked_item_id")
  end

  test "dated item API creates standalone and optionally tracked historical rows without changing the catalog" do
    catalog_entry("Existing reusable item", "reports", 1)
    agenda, unfinished, new_business = historical_agenda
    agenda.dated_agenda_items.create!(
      agenda_section: unfinished,
      position: 1,
      title: "Existing business",
      behavior_type: "business_item",
      active: true
    )
    catalog_count = @organization.agenda_item_catalog_entries.count
    template_item_count = MeetingTypeAgendaItem.count
    sign_in_as(@commander)

    post "/api/dated_agendas/#{agenda.id}/items", params: {
      dated_agenda_section_id: unfinished.id,
      title: "Newsletter",
      summary: "July distribution report",
      body: "The July newsletter was mailed.",
      commander_notes: "Ask whether extra copies remain.",
      behavior_type: "business_item",
      show_wording_on_agenda: true,
      show_wording_in_minutes: false,
      source_key: "must-not-be-accepted",
      seeded_at: Time.current.iso8601
    }, as: :json

    assert_response :created
    standalone = agenda.dated_agenda_items.find(response.parsed_body.dig("dated_agenda_item", "id"))
    assert_equal unfinished, standalone.agenda_section
    assert_equal 2, standalone.position
    assert_equal "Newsletter", standalone.title
    assert_equal "The July newsletter was mailed.", standalone.body.to_plain_text
    assert_equal "Ask whether extra copies remain.", standalone.commander_notes.to_plain_text
    assert_not standalone.show_wording_in_minutes
    assert standalone.active?
    assert_nil standalone.agenda_item_catalog_entry_id
    assert_nil standalone.meeting_type_agenda_item_id
    assert_nil standalone.tracked_item_id
    assert_nil standalone.source_key
    assert_nil standalone.seeded_at

    post "/api/dated_agendas/#{agenda.id}/items", params: {
      dated_agenda_section_id: new_business.id,
      tracked_item_id: @tracker.id,
      title: "Buddy Checks status",
      behavior_type: "business_item"
    }, as: :json

    assert_response :created
    linked = agenda.dated_agenda_items.find(response.parsed_body.dig("dated_agenda_item", "id"))
    assert_equal new_business, linked.agenda_section
    assert_equal 1, linked.position
    assert_equal @tracker, linked.tracked_item
    assert_equal catalog_count, @organization.agenda_item_catalog_entries.count
    assert_equal template_item_count, MeetingTypeAgendaItem.count
  end

  test "standalone dated item creation requires a section and a draft agenda" do
    agenda, unfinished, = historical_agenda
    sign_in_as(@commander)

    assert_no_difference -> { agenda.dated_agenda_items.count } do
      post "/api/dated_agendas/#{agenda.id}/items", params: {
        title: "Missing section",
        behavior_type: "business_item"
      }, as: :json
    end
    assert_response :unprocessable_entity
    assert_match(/dated_agenda_section_id/, response.parsed_body["error"])

    agenda.approve!(@commander)
    assert_no_difference -> { agenda.dated_agenda_items.count } do
      post "/api/dated_agendas/#{agenda.id}/items", params: {
        dated_agenda_section_id: unfinished.id,
        title: "Locked item",
        behavior_type: "business_item"
      }, as: :json
    end
    assert_response :unprocessable_entity
    assert_match(/reopen/i, response.parsed_body["error"])
  end

  test "standalone dated item creation rejects a tracker from another organization" do
    agenda, unfinished, = historical_agenda
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_body = other.meeting_bodies.create!(name: "Membership", slug: "membership")
    other_tracker = other.tracked_items.create!(
      meeting_body: other_body,
      created_by: @commander,
      title: "Other Post business",
      importance: "standard"
    )
    sign_in_as(@commander)

    assert_no_difference -> { agenda.dated_agenda_items.count } do
      post "/api/dated_agendas/#{agenda.id}/items", params: {
        dated_agenda_section_id: unfinished.id,
        tracked_item_id: other_tracker.id,
        title: "Wrong installation",
        behavior_type: "business_item"
      }, as: :json
    end

    assert_response :not_found
  end

  test "dated section reorder requires an exact permutation and returns contiguous order" do
    agenda, unfinished, new_business = historical_agenda
    first = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 4, title: "Buddy Checks", behavior_type: "business_item", active: true)
    second = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 7, title: "Rockers", behavior_type: "business_item", active: true)
    third = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 9, title: "Newsletter", behavior_type: "business_item", active: true)
    other_section_item = agenda.dated_agenda_items.create!(agenda_section: new_business, position: 1, title: "Other section", behavior_type: "business_item", active: true)
    other_agenda, other_unfinished, = historical_agenda
    other_agenda_item = other_agenda.dated_agenda_items.create!(agenda_section: other_unfinished, position: 1, title: "Other agenda", behavior_type: "business_item", active: true)
    sign_in_as(@commander)

    original_versions = [ first, second, third ].index_with(&:lock_version)
    requested_ids = [ third.id, first.id, second.id ]
    post "/api/dated_agendas/#{agenda.id}/sections/#{unfinished.id}/items/reorder", params: {
      dated_agenda_item_ids: requested_ids
    }, as: :json

    assert_response :success
    assert_equal requested_ids, unfinished.agenda_items.active.order(:position).pluck(:id)
    assert_equal [ 1, 2, 3 ], unfinished.agenda_items.active.order(:position).pluck(:position)
    assert_equal requested_ids, response.parsed_body.dig("dated_agenda_section", "items").map { |item| item["id"] }
    [ first, second, third ].each do |item|
      assert_equal unfinished, item.reload.agenda_section
      assert_equal original_versions.fetch(item), item.lock_version
    end

    invalid_orders = [
      [ third.id, first.id ],
      [ third.id, first.id, second.id, 999_999 ],
      [ third.id, first.id, first.id ],
      [ third.id, first.id, other_section_item.id ],
      [ third.id, first.id, other_agenda_item.id ]
    ]
    invalid_orders.each do |ids|
      post "/api/dated_agendas/#{agenda.id}/sections/#{unfinished.id}/items/reorder", params: {
        dated_agenda_item_ids: ids
      }, as: :json

      assert_response :unprocessable_entity
      assert_equal requested_ids, unfinished.agenda_items.active.order(:position).pluck(:id)
    end
  end

  test "dated section reorder scopes the section and rejects locked or unauthorized agendas" do
    agenda, unfinished, = historical_agenda
    first = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 1, title: "First", behavior_type: "business_item", active: true)
    second = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 2, title: "Second", behavior_type: "business_item", active: true)
    other_agenda, other_unfinished, = historical_agenda
    sign_in_as(@commander)

    post "/api/dated_agendas/#{agenda.id}/sections/#{other_unfinished.id}/items/reorder", params: {
      dated_agenda_item_ids: [ first.id, second.id ]
    }, as: :json
    assert_response :not_found

    agenda.approve!(@commander)
    post "/api/dated_agendas/#{agenda.id}/sections/#{unfinished.id}/items/reorder", params: {
      dated_agenda_item_ids: [ second.id, first.id ]
    }, as: :json
    assert_response :unprocessable_entity
    assert_equal [ first.id, second.id ], unfinished.agenda_items.order(:position).pluck(:id)

    sign_in_as(@member)
    post "/api/dated_agendas/#{other_agenda.id}/sections/#{other_unfinished.id}/items/reorder", params: {
      dated_agenda_item_ids: []
    }, as: :json
    assert_response :forbidden
  end

  test "standalone create requires manage agendas" do
    agenda, unfinished, = historical_agenda
    sign_in_as(@member)

    post "/api/dated_agendas/#{agenda.id}/items", params: {
      dated_agenda_section_id: unfinished.id,
      title: "Not allowed",
      behavior_type: "business_item"
    }, as: :json
    assert_response :forbidden
  end

  test "bearer retry replays a dated section reorder without applying it twice" do
    agenda, unfinished, = historical_agenda
    first = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 1, title: "First", behavior_type: "business_item", active: true)
    second = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 2, title: "Second", behavior_type: "business_item", active: true)
    token, plaintext = AgentAccessToken.issue!(user: @commander, name: "Grok", expires_in: 30.days)
    headers = bearer_headers(plaintext, idempotency_key: "july-7-unfinished-order")
    path = "/api/dated_agendas/#{agenda.id}/sections/#{unfinished.id}/items/reorder"
    params = { dated_agenda_item_ids: [ second.id, first.id ] }

    post path, params: params, as: :json, headers: headers
    assert_response :success
    first_body = response.body
    versions_after_first_request = [ first.reload.lock_version, second.reload.lock_version ]

    post path, params: params, as: :json, headers: headers
    assert_response :success
    assert_equal first_body, response.body
    assert_equal versions_after_first_request, [ first.reload.lock_version, second.reload.lock_version ]
    assert_equal [ second.id, first.id ], unfinished.agenda_items.order(:position).pluck(:id)
    assert_equal "completed", token.agent_api_executions.find_by!(idempotency_key: "july-7-unfinished-order").state
  end

  test "tracked business is added to the exact historical section id" do
    agenda, _unfinished, new_business = historical_agenda
    sign_in_as(@commander)

    post "/api/dated_agendas/#{agenda.id}/tracked_items", params: {
      tracked_item_id: @tracker.id,
      dated_agenda_section_id: new_business.id
    }, as: :json

    assert_response :created
    item = agenda.dated_agenda_items.find_by!(tracked_item: @tracker)
    assert_equal new_business, item.agenda_section
    assert_equal new_business.id, response.parsed_body.dig("dated_agenda_item", "dated_agenda_section_id")
  end

  test "dated item API rejects a duplicate tracked item and edits only drafts" do
    agenda, unfinished, = historical_agenda
    first = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 1, title: "First", behavior_type: "business_item", tracked_item: @tracker, active: true)
    second = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 2, title: "Second", behavior_type: "business_item", active: true)
    sign_in_as(@commander)

    patch "/api/dated_agendas/#{agenda.id}/items/#{second.id}", params: { tracked_item_id: @tracker.id }, as: :json
    assert_response :unprocessable_entity
    assert_nil second.reload.tracked_item_id

    agenda.approve!(@commander)
    patch "/api/dated_agendas/#{agenda.id}/items/#{first.id}", params: { summary: "Changed" }, as: :json
    assert_response :unprocessable_entity
    assert_match(/reopen/i, response.parsed_body["error"])
    assert_not_equal "Changed", first.reload.summary
  end

  test "dated item API moves and removes draft snapshot rows" do
    agenda, unfinished, new_business = historical_agenda
    item = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 1, title: "Request approval", behavior_type: "business_item", active: true)
    sign_in_as(@commander)

    patch "/api/dated_agendas/#{agenda.id}/items/#{item.id}", params: {
      dated_agenda_section_id: new_business.id,
      title: "Approve new project"
    }, as: :json
    assert_response :success
    assert_equal new_business, item.reload.agenda_section
    assert_equal "Approve new project", item.title

    delete "/api/dated_agendas/#{agenda.id}/items/#{item.id}", as: :json
    assert_response :success
    assert_not DatedAgendaItem.exists?(item.id)
  end

  test "whole-agenda API deletion removes a published snapshot but keeps trackers" do
    agenda, unfinished, = historical_agenda
    agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 1, title: @tracker.title, behavior_type: "business_item", tracked_item: @tracker, active: true)
    agenda.approve!(@commander)
    agenda.publish!(@commander)
    sign_in_as(@commander)

    delete "/api/dated_agendas/#{agenda.id}", as: :json

    assert_response :success
    assert_not DatedAgenda.exists?(agenda.id)
    assert TrackedItem.exists?(@tracker.id)
    assert_equal "published", response.parsed_body.dig("deleted_dated_agenda", "status")
  end

  test "roll-call API lists office ids and replaces the historical snapshot with vacancies" do
    commander_title = position_title("Commander", 1, required: true)
    adjutant_title = position_title("Adjutant", 2, required: true)
    commander_title.position_assignments.create!(person: @commander.person, starts_on: Date.new(2026, 1, 1))
    agenda, unfinished, = historical_agenda
    roll_call = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 1, title: "Roll Call", behavior_type: "roll_call", active: true)
    sign_in_as(@commander)

    get "/api/position_titles", as: :json
    assert_response :success
    assert_equal [ commander_title.id, adjutant_title.id ], response.parsed_body.fetch("position_titles").map { |title| title["id"] }

    patch "/api/dated_agendas/#{agenda.id}/items/#{roll_call.id}/roll_call", params: {
      entries: [
        { position_title_id: commander_title.id, person_id: nil },
        { position_title_id: adjutant_title.id, person_id: @member.person.id }
      ]
    }, as: :json

    assert_response :success
    rows = response.parsed_body.dig("dated_agenda_item", "roll_call")
    assert_equal [ commander_title.id, adjutant_title.id ], rows.map { |row| row["position_title_id"] }
    assert rows.first["vacant"]
    assert_nil rows.first["person_id"]
    assert_equal @member.person.id, rows.second["person_id"]
    assert_equal @member.person.full_name, rows.second["officer"]
  end

  test "roll-call refresh uses assignments active on the meeting date" do
    commander_title = position_title("Commander", 1, required: true)
    commander_title.position_assignments.create!(
      person: @commander.person,
      starts_on: Date.new(2026, 1, 1),
      ends_on: Date.new(2026, 7, 31)
    )
    commander_title.position_assignments.create!(person: @member.person, starts_on: Date.new(2026, 8, 1))
    agenda, unfinished, = historical_agenda
    roll_call = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 1, title: "Roll Call", behavior_type: "roll_call", active: true)
    roll_call.replace_roll_call_entries!([
      { position_title: commander_title, person: @member.person, office_name: "Commander", person_name: @member.person.full_name }
    ])
    sign_in_as(@commander)

    post "/api/dated_agendas/#{agenda.id}/items/#{roll_call.id}/roll_call/refresh", as: :json

    assert_response :success
    row = response.parsed_body.dig("dated_agenda_item", "roll_call", 0)
    assert_equal @commander.person.id, row["person_id"]
    assert_equal @commander.person.full_name, row["officer"]
  end

  test "roll-call API rejects cross-installation office ids" do
    position_title("Commander", 1, required: true)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_title = other.position_titles.create!(name: "Commander", display_order: 1, active: true)
    agenda, unfinished, = historical_agenda
    roll_call = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 1, title: "Roll Call", behavior_type: "roll_call", active: true)
    sign_in_as(@commander)

    patch "/api/dated_agendas/#{agenda.id}/items/#{roll_call.id}/roll_call", params: {
      entries: [ { position_title_id: other_title.id, person_id: nil } ]
    }, as: :json

    assert_response :not_found
    assert_not_equal other_title.id, roll_call.reload.roll_call_entries.first.position_title_id
  end

  test "roll-call API rejects malformed replacement entries" do
    position_title("Commander", 1, required: true)
    agenda, unfinished, = historical_agenda
    roll_call = agenda.dated_agenda_items.create!(agenda_section: unfinished, position: 1, title: "Roll Call", behavior_type: "roll_call", active: true)
    original_ids = roll_call.roll_call_entry_ids
    sign_in_as(@commander)

    patch "/api/dated_agendas/#{agenda.id}/items/#{roll_call.id}/roll_call", params: {
      entries: [ "not an officer row" ]
    }, as: :json

    assert_response :unprocessable_entity
    assert_equal original_ids, roll_call.reload.roll_call_entry_ids
  end

  private

  def create_user(label, capabilities: [])
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end

  def catalog_entry(title, category, position)
    @organization.agenda_item_catalog_entries.create!(
      title: title,
      category: category,
      behavior_type: "business_item",
      position: position,
      active: true
    )
  end

  def historical_agenda
    agenda = @organization.dated_agendas.create!(
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: Time.zone.local(2026, 7, 7, 18, 30),
      title: "Membership Meeting — 07 JUL 2026",
      status: "draft"
    )
    unfinished = agenda.default_agenda_section
    unfinished.update!(title: "Unfinished Business")
    new_business = agenda.dated_agenda_sections.create!(title: "New Business", position: 2)
    [ agenda, unfinished, new_business ]
  end

  def position_title(name, display_order, required: false)
    @organization.position_titles.create!(
      name: name,
      display_order: display_order,
      required_by_default: required,
      active: true
    )
  end

  def bearer_headers(plaintext, idempotency_key: nil)
    { "Authorization" => "Bearer #{plaintext}" }.tap do |headers|
      headers["Idempotency-Key"] = idempotency_key if idempotency_key
    end
  end
end
