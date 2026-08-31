require "test_helper"

class ApiMinutesDraftApiTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago, title: "August Meeting")
    @manager = create_user("Manager", "manage_minutes")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @transcript = MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @manager,
      retention_policy: "delete_after_acceptance",
      pasted_text: "Commander opened the meeting.\nThe membership discussed the event.\nA motion was made and passed."
    ).call
    sign_in_as(@manager)
  end

  test "agent can request a durable background drafting run" do
    assert_enqueued_with(job: MinutesDraftGenerationJob) do
      post "/api/meetings/#{@meeting.id}/minutes/draft_runs", as: :json
    end

    assert_response :accepted
    run = @minutes.draft_runs.find(response.parsed_body.dig("draft_run", "id"))
    assert_equal "pending", run.status
    assert_equal @manager, run.requested_by
    assert_equal MinutesDraftProviders::Openai::MODEL, response.parsed_body.dig("draft_run", "model")

    get "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{run.id}", as: :json
    assert_response :success
    assert_nil response.parsed_body.dig("draft_run", "transcript_content")
    assert_not_includes response.body, "Commander opened"
  end

  test "agent explicitly reviews narrative and roster-verified outcome suggestions" do
    item = @minutes.sections.first.items.create!(
      title: "Car show",
      behavior_type: "business_item",
      position: 1
    )
    run = succeeded_run
    narrative = run.suggestions.create!(
      kind: "item_summary",
      minutes_item: item,
      payload: { "body" => "Members reviewed the event plan and volunteer needs." },
      source_start_line: 2,
      source_end_line: 2,
      confidence: "high",
      missing_facts: []
    )
    outcome = run.suggestions.create!(
      kind: "outcome",
      minutes_item: item,
      payload: {
        "kind" => "motion",
        "text" => "Approve the event budget.",
        "disposition" => "not_recorded",
        "mover_name" => "Dean",
        "seconder_name" => "Jim"
      },
      source_start_line: 3,
      source_end_line: 3,
      confidence: "medium",
      missing_facts: [ "Confirm the result", "Confirm mover and seconder" ]
    )
    mover = Person.create!(first_name: "Dean", last_name: "Member")
    seconder = Person.create!(first_name: "James", last_name: "Member")

    patch "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{run.id}/suggestions/#{narrative.id}/use", as: :json
    assert_response :success
    assert_equal "used", narrative.reload.review_state
    assert_equal "Members reviewed the event plan and volunteer needs.", item.reload.body.to_plain_text

    patch "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{run.id}/suggestions/#{outcome.id}/use", params: {
      disposition: "adopted",
      mover_person_id: mover.id,
      seconder_person_id: seconder.id
    }, as: :json
    assert_response :success
    applied = item.outcomes.last
    assert_equal "Passed", response.parsed_body.dig("minutes", "sections").flat_map { |section| section["items"] }
      .find { |row| row["id"] == item.id }.dig("outcomes", 0, "disposition_label")
    assert_equal mover, applied.mover_person
    assert_equal "Dean Member", applied.mover_name
    assert_equal seconder, applied.seconder_person
    assert_equal "James Member", applied.seconder_name
  end

  test "agent reviews the complete suggested attendance sheet" do
    attendance = @minutes.attendance_entries.create!(
      office_name: "Commander",
      person_name: "Test Officer",
      status: "not_recorded",
      position: 1
    )
    run = succeeded_run
    suggestion = run.suggestions.create!(
      kind: "attendance",
      minutes_attendance_entry: attendance,
      payload: { "status" => "present" },
      source_start_line: 1,
      source_end_line: 1,
      confidence: "high",
      missing_facts: []
    )

    patch "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{run.id}/attendance", params: {
      attendance: [ { id: attendance.id, status: "present", lock_version: attendance.lock_version } ]
    }, as: :json

    assert_response :success
    assert_equal "present", attendance.reload.status
    assert_equal "used", suggestion.reload.review_state
    assert_equal 0, response.parsed_body.dig("draft_run", "review_counts", "unreviewed").to_i
  end

  test "failed runs retry as linked attempts and discard or restore without deletion" do
    failed = prepared_run
    failed.update!(status: "failed", error_category: "timeout", completed_at: Time.current)

    assert_enqueued_with(job: MinutesDraftGenerationJob) do
      post "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{failed.id}/retry", as: :json
    end
    assert_response :accepted
    retry_run = @minutes.draft_runs.find(response.parsed_body.dig("draft_run", "id"))
    assert_equal failed, retry_run.retry_of
    assert_equal "pending", retry_run.status
    assert failed.reload.persisted?

    patch "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{failed.id}/discard", as: :json
    assert_response :success
    assert failed.reload.discarded?
    assert_equal @manager, failed.discarded_by

    patch "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{failed.id}/restore", as: :json
    assert_response :success
    assert_not failed.reload.discarded?
  end

  test "jobs API exposes safe queue and run summaries" do
    failed = prepared_run
    failed.update!(status: "failed", error_category: "provider_error", completed_at: Time.current)

    get "/api/jobs", params: { filter: "attention" }, as: :json

    assert_response :success
    assert response.parsed_body["queue"].key?("worker_available")
    assert_equal failed.id, response.parsed_body.dig("minutes_draft_runs", 0, "id")
    assert_equal 1, response.parsed_body["attention_count"]
    assert_not_includes response.body, @transcript.source_text
  end

  private

  def prepared_run
    MinutesDrafting::Generate.prepare(minutes: @minutes, requester: @manager)
  end

  def succeeded_run
    prepared_run.tap { |run| run.update!(status: "succeeded", started_at: 1.second.ago, completed_at: Time.current) }
  end

  def create_user(label, capability)
    person = Person.create!(first_name: "Test", last_name: "#{label}-#{SecureRandom.hex(3)}")
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    user.permission_grants.create!(capability: capability)
    user
  end
end
