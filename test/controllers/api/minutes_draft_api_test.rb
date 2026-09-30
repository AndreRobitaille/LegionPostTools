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

  test "Endeavor proposal API requires explicit identity choice and creation authority" do
    item = @minutes.sections.first.items.create!(title: "Breakfast", behavior_type: "business_item", position: 1)
    run = succeeded_run
    proposal = run.suggestions.create!(kind: "endeavor_proposal", minutes_item: item,
      payload: { "title" => "Community breakfast", "body" => "Plan a breakfast.", "reason" => "Continuing work." },
      source_start_line: 2, source_end_line: 2, confidence: "high", missing_facts: [])
    path = "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{run.id}/suggestions/#{proposal.id}/use"

    assert_no_difference "Endeavor.count" do
      patch path, as: :json
      assert_response :unprocessable_entity
      patch path, params: { endeavor_action: "create", title: "Breakfast", body: "Plan it.", lock_version: item.lock_version }, as: :json
      assert_response :unprocessable_entity
    end
    assert_nil item.reload.endeavor_id
    assert proposal.reload.unreviewed?

    PermissionGrant.create!(user: @manager, capability: "manage_agendas")
    assert_difference "Endeavor.count", 1 do
      patch path, params: { endeavor_action: "create", title: "Community breakfast", body: "Plan a breakfast.", lock_version: item.lock_version }, as: :json
    end
    assert_response :success
    assert_equal "used", proposal.reload.review_state
    assert_equal @manager, item.reload.endeavor.created_by
    assert_no_difference "Endeavor.count" do
      patch path, params: { endeavor_action: "create", title: "Another breakfast", lock_version: 0 }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "Endeavor proposal API permits confirmed existing links but rejects stale or foreign identities" do
    item = @minutes.sections.first.items.create!(title: "Breakfast", behavior_type: "business_item", position: 1)
    proposal = succeeded_run.suggestions.create!(kind: "endeavor_proposal", minutes_item: item,
      payload: { "title" => "Breakfast", "body" => "Plan it.", "reason" => "Continuing work." },
      source_start_line: 2, source_end_line: 2, confidence: "high", missing_facts: [])
    existing = @organization.endeavors.create!(title: "Breakfast planning", created_by: @manager, importance: "standard", status: "active")
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.endeavors.create!(title: "Other work", created_by: @manager, importance: "standard", status: "active")
    path = "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{proposal.minutes_draft_run_id}/suggestions/#{proposal.id}/use"
    patch path, params: { endeavor_action: "link", endeavor_id: foreign.id, lock_version: item.lock_version }, as: :json
    assert_response :unprocessable_entity
    assert_nil item.reload.endeavor_id
    version = item.lock_version
    item.update!(title: "Changed discussion")
    patch path, params: { endeavor_action: "link", endeavor_id: existing.id, lock_version: version }, as: :json
    assert_response :unprocessable_entity
    assert proposal.reload.unreviewed?
    patch path, params: { endeavor_action: "link", endeavor_id: existing.id, lock_version: item.lock_version }, as: :json
    assert_response :success
    assert_equal existing, item.reload.endeavor
    assert_equal "edited", proposal.reload.review_state
  end

  test "AI proposal evidence is explicit normalized restricted and absent after purge" do
    @transcript.update!(content: "Commander opened the meeting.\n\n  The membership   discussed the event.\nA motion was made and passed.")
    item = @minutes.sections.first.items.create!(title: "Breakfast", behavior_type: "business_item", position: 1)
    run = succeeded_run
    proposal = endeavor_proposal(run, item)
    path = "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{run.id}"
    _token, secret = AgentAccessToken.issue!(user: @manager, name: "Evidence review", expires_in: 1.day)
    headers = { "Authorization" => "Bearer #{secret}" }
    get path, headers: headers, as: :json
    assert_response :success
    assert_not response.parsed_body.dig("draft_run", "suggestions", 0).key?("source_excerpt")
    get path, params: { include_source: true }, headers: headers, as: :json
    assert_response :success
    returned = response.parsed_body.dig("draft_run", "suggestions", 0)
    assert_equal proposal.id, returned["id"]
    assert_equal "L0002 The membership discussed the event.", returned["source_excerpt"]
    assert_equal proposal.payload, returned["payload"]
    assert_includes response.headers["Cache-Control"], "no-store"
    @transcript.update!(content: nil, purged_at: Time.current, purged_by: @manager)
    get path, params: { include_source: true }, headers: headers, as: :json
    assert_response :success
    assert_nil response.parsed_body.dig("draft_run", "suggestions", 0, "source_excerpt")
    @manager.permission_grants.find_by!(capability: "manage_minutes").destroy!
    get path, params: { include_source: true }, headers: headers, as: :json
    assert_response :forbidden
    assert_not_includes response.body, "membership discussed"
  end

  test "bearer AI corrections and dismissal preserve original evidence and review provenance" do
    PermissionGrant.create!(user: @manager, capability: "manage_agendas")
    item = @minutes.sections.first.items.create!(title: "Breakfast", body: "Members agreed to recurring work.",
      agenda_body: "Explore a breakfast.", behavior_type: "business_item", position: 1)
    proposal = endeavor_proposal(succeeded_run, item)
    original_payload = proposal.payload.deep_dup
    original_record = [ item.title, item.body.to_plain_text, item.agenda_body.to_plain_text ]
    token, secret = AgentAccessToken.issue!(user: @manager, name: "Minutes review", expires_in: 1.day)
    headers = { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => "edited-ai-breakfast" }
    path = "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{proposal.minutes_draft_run_id}/suggestions/#{proposal.id}/edit"
    payload = { endeavor_action: "create", title: "Monthly community breakfast", body: "Plan recurring breakfasts.", lock_version: item.lock_version }
    assert_difference "Endeavor.count", 1 do
      patch path, params: payload, headers: headers, as: :json
    end
    assert_response :success
    assert_equal "edited", response.parsed_body.dig("suggestion", "review_state")
    assert_equal original_payload, response.parsed_body.dig("suggestion", "payload")
    assert_equal "Endeavor", response.parsed_body.dig("suggestion", "applied_record_type")
    assert_equal item.reload.endeavor_id, response.parsed_body.dig("suggestion", "applied_record_id")
    assert_equal @manager, proposal.reload.reviewed_by
    assert_not_nil proposal.reviewed_at
    assert_equal original_record, [ item.title, item.body.to_plain_text, item.agenda_body.to_plain_text ]
    assert_no_difference "Endeavor.count" do
      patch path, params: payload, headers: headers, as: :json
    end
    assert_response :success
    assert_equal 200, token.agent_api_executions.find_by!(idempotency_key: "edited-ai-breakfast").response_status

    second_item = @minutes.sections.first.items.create!(title: "Another discussion", behavior_type: "business_item", position: 2)
    dismissed = endeavor_proposal(proposal.minutes_draft_run, second_item)
    discard_path = "/api/meetings/#{@meeting.id}/minutes/draft_runs/#{dismissed.minutes_draft_run_id}/suggestions/#{dismissed.id}/discard"
    assert_no_difference "Endeavor.count" do
      patch discard_path, headers: headers.merge("Idempotency-Key" => "dismiss-ai-work"), as: :json
    end
    assert_response :success
    assert_equal "discarded", response.parsed_body.dig("suggestion", "review_state")
    assert_equal @manager, dismissed.reload.reviewed_by
    assert_not_nil dismissed.reviewed_at
    assert_nil dismissed.applied_record_id
    assert_nil second_item.reload.endeavor_id
    assert_equal original_payload, dismissed.payload
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

  def endeavor_proposal(run, item)
    run.suggestions.create!(kind: "endeavor_proposal", minutes_item: item,
      payload: { "title" => "Breakfast", "body" => "Plan a breakfast.", "reason" => "Continuing work.", "endeavor_id" => nil },
      source_start_line: 2, source_end_line: 2, confidence: "high", missing_facts: [])
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
