require "test_helper"

class ApiMinutesApiTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Test Post",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(
      organization: @organization,
      meeting_body: @body,
      starts_at: 1.day.ago,
      title: "August Membership"
    )
    @manager = create_user("Manager", "manage_minutes")
    @viewer = create_user("Viewer", "view_internal_records")
    @member = create_user("Member")
  end

  test "agent can add and explicitly read a restricted transcript then seed minutes" do
    sign_in_as(@manager)

    post "/api/meetings/#{@meeting.id}/transcript", params: {
      transcript_content: "Commander opened the meeting.\nA motion passed.",
      retention_policy: "delete_after_acceptance"
    }, as: :json

    assert_response :created
    assert_nil response.parsed_body.dig("transcript", "content")
    transcript = @meeting.reload.transcript
    assert_equal @manager, transcript.created_by

    get "/api/meetings/#{@meeting.id}/transcript", as: :json
    assert_response :success
    assert_nil response.parsed_body.dig("transcript", "content")

    get "/api/meetings/#{@meeting.id}/transcript", params: { include_content: true }, as: :json
    assert_response :success
    assert_equal transcript.source_text, response.parsed_body.dig("transcript", "content")

    post "/api/meetings/#{@meeting.id}/minutes", as: :json
    assert_response :created
    assert_equal "draft", response.parsed_body.dig("minutes", "status")
    assert_equal [ "Meeting record" ], response.parsed_body.dig("minutes", "sections").map { |section| section["title"] }

    get "/api/meetings/#{@meeting.id}", as: :json
    assert_equal transcript.id, response.parsed_body.dig("meeting", "transcript", "id")
    assert_equal @meeting.minutes.id, response.parsed_body.dig("meeting", "minutes", "id")
    assert_not_includes response.body, "Commander opened"
  end

  test "internal record viewer can read but cannot mutate minutes or transcript" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @manager,
      retention_policy: "retain_restricted",
      pasted_text: "Restricted source"
    ).call
    sign_in_as(@viewer)

    get "/api/meetings/#{@meeting.id}/minutes", as: :json
    assert_response :success
    assert_equal minutes.id, response.parsed_body.dig("minutes", "id")

    get "/api/meetings/#{@meeting.id}/transcript", params: { include_content: true }, as: :json
    assert_response :success
    assert_equal "Restricted source", response.parsed_body.dig("transcript", "content")

    patch "/api/meetings/#{@meeting.id}/minutes", params: { title: "Changed" }, as: :json
    assert_response :forbidden
    assert_not_equal "Changed", minutes.reload.title

    post "/api/meetings/#{@meeting.id}/transcript", params: {
      transcript_content: "Replacement",
      retention_policy: "retain_restricted"
    }, as: :json
    assert_response :forbidden
  end

  test "agent can build reorder and edit the structured draft" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    first_section = minutes.sections.first
    attendance = minutes.attendance_entries.create!(
      office_name: "Commander",
      person_name: "Test Officer",
      status: "not_recorded",
      position: 1
    )
    sign_in_as(@manager)

    post "/api/meetings/#{@meeting.id}/minutes/sections", params: { title: "Good of the Legion" }, as: :json
    assert_response :created
    second_section = minutes.sections.find(response.parsed_body.dig("section", "id"))

    post "/api/meetings/#{@meeting.id}/minutes/items", params: {
      minutes_section_id: first_section.id,
      title: "Car show",
      body: "Members reviewed attendance and assignments."
    }, as: :json
    assert_response :created
    item = minutes.items.find(response.parsed_body.dig("item", "id"))
    item.update!(agenda_body: "Review the car show plan.")

    post "/api/meetings/#{@meeting.id}/minutes/outcomes", params: {
      minutes_item_id: item.id,
      kind: "motion",
      text: "Approve the event budget.",
      disposition: "lost",
      mover_unidentified: true,
      seconder_unidentified: true
    }, as: :json
    assert_response :created
    outcome = item.outcomes.find(response.parsed_body.dig("outcome", "id"))
    assert_equal "Did not pass", response.parsed_body.dig("outcome", "disposition_label")

    post "/api/meetings/#{@meeting.id}/minutes/sections/reorder", params: {
      ids: [ second_section.id, first_section.id ]
    }, as: :json
    assert_response :success
    assert_equal [ second_section.id, first_section.id ], minutes.sections.reload.pluck(:id)

    patch "/api/meetings/#{@meeting.id}/minutes/items/#{item.id}", params: {
      minutes_section_id: second_section.id,
      title: "Car and bike show",
      lock_version: item.lock_version
    }, as: :json
    assert_response :success
    assert_equal second_section, item.reload.minutes_section

    patch "/api/meetings/#{@meeting.id}/minutes/attendance", params: {
      attendance: [ { id: attendance.id, status: "present", lock_version: attendance.lock_version } ]
    }, as: :json
    assert_response :success
    assert_equal "present", attendance.reload.status

    get "/api/meetings/#{@meeting.id}/minutes", as: :json
    assert_response :success
    returned_item = response.parsed_body.dig("minutes", "sections").flat_map { |section| section["items"] }.find { |row| row["id"] == item.id }
    assert_equal "Review the car show plan.", returned_item["agenda_wording"]
    assert_equal "Members reviewed attendance and assignments.", returned_item["body"]
    assert_equal outcome.id, returned_item.dig("outcomes", 0, "id")

    post "/api/meetings/#{@meeting.id}/minutes/sections/reorder", params: { ids: [ first_section.id ] }, as: :json
    assert_response :unprocessable_entity
  end

  test "draft mutations reject locked minutes and PDF remains a read-only artifact" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    minutes.update!(status: "approved")
    sign_in_as(@manager)

    post "/api/meetings/#{@meeting.id}/minutes/sections", params: { title: "Late section" }, as: :json
    assert_response :unprocessable_entity
    assert_match(/draft/i, response.parsed_body["error"])

    renderer = ->(minutes:) { "%PDF-1.7\n#{minutes.id}" }
    with_stubbed_class_method(MeetingMinutesPdf, :render, renderer) do
      get "/api/meetings/#{@meeting.id}/minutes/print"
    end

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers.fetch("Content-Disposition"))
  end

  test "bearer minutes creation is idempotent" do
    _token, plaintext = AgentAccessToken.issue!(user: @manager, name: "Officer agent", expires_in: 30.days)
    headers = {
      "Authorization" => "Bearer #{plaintext}",
      "Idempotency-Key" => "seed-august-minutes"
    }

    assert_difference -> { MeetingMinutes.count }, 1 do
      post "/api/meetings/#{@meeting.id}/minutes", headers: headers, as: :json
      assert_response :created
      first_body = response.body

      post "/api/meetings/#{@meeting.id}/minutes", headers: headers, as: :json
      assert_response :created
      assert_equal first_body, response.body
    end
  end

  test "plain member cannot read draft records" do
    MeetingMinutes.create_from_meeting!(meeting: @meeting)
    sign_in_as(@member)

    get "/api/meetings/#{@meeting.id}/minutes", as: :json
    assert_response :forbidden
  end

  private

  def create_user(label, capability = nil)
    person = Person.create!(first_name: "Test", last_name: "#{label}-#{SecureRandom.hex(3)}")
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: capability) if capability
    user
  end
end
