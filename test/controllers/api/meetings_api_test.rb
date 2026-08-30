require "test_helper"

class ApiMeetingsApiTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    person = Person.create!(first_name: "Test", last_name: "Manager")
    @manager = User.create!(person: person, email_address: "manager@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @manager, capability: "manage_agendas")
    sign_in_as(@manager)
  end

  test "create list show and update a meeting occurrence" do
    assert_difference -> { Meeting.count }, 1 do
      post "/api/meetings", params: {
        meeting_body_id: @body.id,
        meeting_type_id: @type.id,
        starts_at: Time.zone.local(2026, 9, 8, 19).iso8601,
        location_name: "Legion Hall",
        location_address: "123 Main Street"
      }, as: :json
    end

    assert_response :created
    payload = response.parsed_body.fetch("meeting")
    assert_equal "Legion Hall", payload["location_name"]
    assert_nil payload["agenda"]
    meeting = Meeting.find(payload["id"])

    get "/api/meetings", as: :json
    assert_response :success
    assert_equal meeting.id, response.parsed_body.dig("meetings", 0, "id")

    patch "/api/meetings/#{meeting.id}", params: { title: "Changed Meeting", lock_version: meeting.lock_version }, as: :json
    assert_response :success
    assert_equal "Changed Meeting", meeting.reload.title

    get "/api/meetings/#{meeting.id}", as: :json
    assert_equal "Changed Meeting", response.parsed_body.dig("meeting", "title")
  end

  test "dated agenda creation attaches to an existing meeting" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now, title: "Agenda Meeting")

    post "/api/dated_agendas", params: { meeting_id: meeting.id }, as: :json

    assert_response :created
    assert_equal meeting.id, response.parsed_body.dig("dated_agenda", "meeting_id")
    assert_equal meeting.id, meeting.reload.dated_agenda.meeting_id
  end

  test "meeting with an agenda cannot be deleted" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now)

    delete "/api/meetings/#{agenda.meeting_id}", as: :json

    assert_response :unprocessable_entity
    assert_match(/Remove the meeting's agenda/, response.parsed_body["error"])
  end
end
