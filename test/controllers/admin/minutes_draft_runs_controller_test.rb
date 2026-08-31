require "test_helper"

class Admin::MinutesDraftRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Post Hall",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago, title: "July Membership")
    @manager = create_user_with("manage_minutes")
    @endeavor = @organization.endeavors.create!(
      title: "Veteran flag outreach",
      summary: "Provide flags to local veterans and families.",
      importance: "standard",
      status: "active",
      created_by: @manager
    )
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @item = @minutes.sections.first.items.create!(title: "Service report", behavior_type: "report_slot", position: 1)
    @transcript = MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @manager,
      retention_policy: "delete_after_acceptance",
      pasted_text: "The service officer reported that five veterans received assistance."
    ).call
  end

  test "minutes manager sees the external-processing disclosure before drafting" do
    sign_in_as(@manager)

    get new_admin_meeting_minutes_draft_run_path(@meeting)

    assert_response :success
    assert_select "h1", text: "Create the first pass"
    assert_select ".ai-provider-note", text: /sent to the OpenAI API/
    assert_select ".ai-draft-disclosure-main", text: /Endeavor titles and summaries/
    assert_select "input[type='submit'][value='Send transcript and create draft']"
    assert_select ".ai-draft-no-bulk", text: /no accept-all action/i
  end

  test "a proposed Endeavor link is visible and editable before use" do
    run = create_run!
    suggestion = run.suggestions.create!(
      minutes_section: @minutes.sections.first,
      kind: "additional_item",
      payload: {
        title: "Flag outreach",
        body: "Members discussed providing flags to veterans.",
        endeavor_id: @endeavor.id,
        endeavor_title: @endeavor.title
      },
      source_start_line: 1,
      source_end_line: 1,
      confidence: "high",
      missing_facts: []
    )
    sign_in_as(@manager)

    get admin_meeting_minutes_draft_run_path(@meeting, run)

    assert_response :success
    assert_select ".ai-suggestion-endeavor", text: /Related Endeavor.*Veteran flag outreach/

    get edit_admin_meeting_minutes_draft_suggestion_path(@meeting, suggestion)

    assert_response :success
    assert_select "select[name='minutes_draft_suggestion[endeavor_id]'] option[selected]", text: @endeavor.title
  end

  test "draft review keeps every suggestion as an individual human decision" do
    run = create_run!
    run.suggestions.create!(
      minutes_item: @item,
      kind: "item_summary",
      payload: { body: "The service officer reported assisting five veterans." },
      source_start_line: 1,
      source_end_line: 1,
      confidence: "high",
      missing_facts: []
    )
    sign_in_as(@manager)

    get admin_meeting_minutes_draft_run_path(@meeting, run)

    assert_response :success
    assert_select ".ai-suggestion-card", count: 1
    assert_select ".ai-suggestion-source-ribbon", text: /L0001/
    assert_select "button", text: "Add to minutes"
    assert_select "a", text: "Edit before using"
    assert_select "button", text: "Discard"
    assert_select "button", text: /accept all/i, count: 0
    assert_select ".ai-source-evidence pre", text: /five veterans received assistance/
  end

  test "draft review presents attendance as one radio sheet with AI choices preselected" do
    commander = @minutes.attendance_entries.create!(
      office_name: "Commander",
      person_name: "C. Officer",
      status: "not_recorded",
      position: 1
    )
    vacant = @minutes.attendance_entries.create!(
      office_name: "First Vice Commander",
      status: "vacant",
      position: 2
    )
    run = create_run!
    run.suggestions.create!(
      minutes_attendance_entry: commander,
      kind: "attendance",
      payload: { status: "present" },
      source_start_line: 1,
      source_end_line: 1,
      confidence: "high",
      missing_facts: []
    )
    sign_in_as(@manager)

    get admin_meeting_minutes_draft_run_path(@meeting, run)

    assert_response :success
    assert_select ".ai-attendance-sheet", count: 1
    assert_select "input[type='radio'][name='attendance_entries[#{commander.id}][status]'][value='present'][checked]"
    assert_select "input[type='radio'][name='attendance_entries[#{commander.id}][status]'][value='not_recorded']"
    assert_select ".ai-attendance-officer small", text: /AI suggests present.*L0001/
    assert_select ".ai-attendance-row--vacant", text: /First Vice Commander.*Vacant/
    assert_select "input[type='submit'][value='Save attendance review']"
    assert_select ".ai-suggestion-card", count: 0
  end

  test "attendance sheet records AI matches and human corrections in one bounded review" do
    commander = @minutes.attendance_entries.create!(
      office_name: "Commander",
      person_name: "C. Officer",
      status: "not_recorded",
      position: 1
    )
    adjutant = @minutes.attendance_entries.create!(
      office_name: "Adjutant",
      person_name: "A. Officer",
      status: "not_recorded",
      position: 2
    )
    vacant = @minutes.attendance_entries.create!(office_name: "First Vice Commander", status: "vacant", position: 3)
    run = create_run!
    commander_suggestion = attendance_suggestion!(run, commander, "present")
    adjutant_suggestion = attendance_suggestion!(run, adjutant, "present")
    sign_in_as(@manager)

    patch admin_meeting_minutes_draft_run_attendance_review_path(@meeting, run),
      params: {
        attendance_entries: {
          commander.id.to_s => { status: "present", lock_version: commander.lock_version },
          adjutant.id.to_s => { status: "excused", lock_version: adjutant.lock_version },
          vacant.id.to_s => { status: "vacant", lock_version: vacant.lock_version }
        }
      },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_select "turbo-stream[action='replace'][target='attendance_review']"
    assert_select "turbo-stream[action='replace'][target='ai_review_counter']"
    assert_equal "present", commander.reload.status
    assert_equal "excused", adjutant.reload.status
    assert_equal "vacant", vacant.reload.status
    assert_equal "used", commander_suggestion.reload.review_state
    assert_equal "edited", adjutant_suggestion.reload.review_state
    assert_equal @manager, commander_suggestion.reviewed_by
    assert_equal @manager, adjutant_suggestion.reviewed_by
  end

  test "using one suggestion changes only its ordinary minutes field" do
    run = create_run!
    suggestion = run.suggestions.create!(
      minutes_item: @item,
      kind: "item_summary",
      payload: { body: "The service officer reported assisting five veterans." },
      source_start_line: 1,
      source_end_line: 1,
      confidence: "high",
      missing_facts: []
    )
    sign_in_as(@manager)

    post use_admin_meeting_minutes_draft_suggestion_path(@meeting, suggestion)

    assert_redirected_to admin_meeting_minutes_draft_run_path(@meeting, run)
    assert_equal "The service officer reported assisting five veterans.", @item.reload.body.to_plain_text.squish
    assert_equal "used", suggestion.reload.review_state
    assert_equal @manager, suggestion.reviewed_by
  end

  test "using a suggestion through Turbo replaces its card and counter without a redirect" do
    run = create_run!
    suggestion = run.suggestions.create!(
      minutes_item: @item,
      kind: "item_summary",
      payload: { body: "The service officer reported assisting five veterans." },
      source_start_line: 1,
      source_end_line: 1,
      confidence: "high",
      missing_facts: []
    )
    sign_in_as(@manager)

    post use_admin_meeting_minutes_draft_suggestion_path(@meeting, suggestion),
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_select "turbo-stream[action='replace'][target='review_minutes_draft_suggestion_#{suggestion.id}']"
    assert_select "turbo-stream[action='replace'][target='ai_review_counter']"
    assert_select ".ai-suggestion-complete", text: /Added.*Reviewed/
    assert_select ".app-flash", count: 0
  end

  test "internal viewers cannot initiate or review AI draft runs" do
    viewer = create_user_with("view_internal_records")
    run = create_run!
    sign_in_as(viewer)

    get new_admin_meeting_minutes_draft_run_path(@meeting)
    assert_redirected_to root_path

    get admin_meeting_minutes_draft_run_path(@meeting, run)
    assert_redirected_to root_path
  end

  private

  def create_run!
    @minutes.draft_runs.create!(
      meeting_transcript: @transcript,
      requested_by: @manager,
      provider: "openai",
      model: "gpt-5.6-sol",
      reasoning_effort: "high",
      text_verbosity: "medium",
      prompt_version: MinutesDrafting::Prompt::VERSION,
      prompt_sha256: MinutesDrafting::Prompt.sha256,
      schema_version: MinutesDrafting::Prompt::SCHEMA_VERSION,
      source_sha256: @transcript.sha256_digest,
      source_line_count: 1,
      status: "succeeded",
      completed_at: Time.current
    )
  end

  def attendance_suggestion!(run, entry, status)
    run.suggestions.create!(
      minutes_attendance_entry: entry,
      kind: "attendance",
      payload: { status: status },
      source_start_line: 1,
      source_end_line: 1,
      confidence: "high",
      missing_facts: []
    )
  end

  def create_user_with(*capabilities)
    person = Person.create!(first_name: "Minutes", last_name: SecureRandom.hex(3))
    user = User.create!(person: person, email_address: "minutes-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
