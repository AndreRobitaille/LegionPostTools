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

  def create_user_with(*capabilities)
    person = Person.create!(first_name: "Minutes", last_name: SecureRandom.hex(3))
    user = User.create!(person: person, email_address: "minutes-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
