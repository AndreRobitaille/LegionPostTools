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

  test "ordinary member and personal delegate can read occurrences without officer duties" do
    past = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.ago, title: "Past occurrence")
    upcoming = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.from_now, title: "Upcoming occurrence")
    member = User.create!(person: Person.create!(first_name: "Ordinary", last_name: "Member"), email_address: "ordinary@example.com")
    _token, plaintext = AgentAccessToken.issue!(user: member, name: "Member delegate", expires_in: 1.day)
    sign_in_as(member)

    [ {}, { "Authorization" => "Bearer #{plaintext}" } ].each do |headers|
      get "/api/meetings", headers:, as: :json
      assert_response :success
      assert_equal [ upcoming.id, past.id ], response.parsed_body.fetch("meetings").map { |row| row.fetch("id") }
      get "/api/meetings/#{past.id}", headers:, as: :json
      assert_response :success
      assert_equal "Past occurrence", response.parsed_body.dig("meeting", "title")
      assert_equal [], member.reload.permission_grants.pluck(:capability)
    end
  end

  test "agenda-only meeting responses exclude restricted transcript and working minutes including update echoes" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.ago, title: "Meeting occurrence")
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    minutes.update!(title: "Private working heading")
    source = "Restricted source evidence."
    MeetingTranscript.create!(organization: @organization, meeting:, created_by: @manager, source_kind: "pasted_text",
      content: source, original_filename: "private-source.txt", byte_size: source.bytesize, media_type: "text/plain",
      sha256_digest: Digest::SHA256.hexdigest(source), retention_policy: "retain_restricted")
    original_minutes = minutes.reload.attributes

    [ :list, :show, :update ].each do |action|
      case action
      when :list then get "/api/meetings", as: :json
      when :show then get "/api/meetings/#{meeting.id}", as: :json
      when :update then patch "/api/meetings/#{meeting.id}", params: { website_title: "Reviewed notice heading" }, as: :json
      end
      assert_response :success
      payload = action == :list ? response.parsed_body.fetch("meetings").find { |row| row["id"] == meeting.id } : response.parsed_body.fetch("meeting")
      assert_equal({ "transcript" => nil, "minutes" => nil }, payload.slice("transcript", "minutes"), "#{action} cannot disclose either restricted record")
      assert_nil payload.fetch("transcript"), "#{action} must respect the existing transcript-read boundary"
      assert_nil payload.fetch("minutes"), "#{action} must respect the existing working-minutes boundary"
      assert_not_includes response.body, "Private working heading"
      assert_not_includes response.body, "private-source.txt"
      assert_equal original_minutes, minutes.reload.attributes
    end
    assert_equal "Reviewed notice heading", meeting.reload.website_title
  end
end
