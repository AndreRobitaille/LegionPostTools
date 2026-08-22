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

  private

  def create_user(label, capabilities: [])
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
