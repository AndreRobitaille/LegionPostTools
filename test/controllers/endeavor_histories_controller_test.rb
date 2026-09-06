require "test_helper"

class EndeavorHistoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Installation.singleton.update!(setup_completed_at: Time.current)
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @manager = make_user("manager", manager: true)
    @member = make_user("member")
    @endeavor = @organization.endeavors.create!(title: "Car Show", created_by: @manager)
  end

  test "member sees history but no management controls and cannot access or mutate AI history" do
    sign_in_as(@member)
    get endeavor_path(@endeavor)
    assert_response :success
    assert_select "a[href=?]", admin_endeavor_history_path(@endeavor), count: 0
    get admin_endeavor_history_path(@endeavor)
    assert_redirected_to root_path
    assert_no_difference "EndeavorHistoryGuidance.count" do
      post admin_endeavor_history_path(@endeavor), params: { operation: "guidance", guidance: "Bad", lock_version: @endeavor.lock_version }
    end
    get api_endeavor_history_path(@endeavor), as: :json
    assert_response :forbidden
  end

  test "manager can inspect history and save guidance with optimistic locking" do
    sign_in_as(@manager)
    get admin_endeavor_history_path(@endeavor)
    assert_response :success
    assert_select "h1", text: "AI history"
    version = @endeavor.lock_version
    post admin_endeavor_history_path(@endeavor), params: { operation: "guidance", guidance: "The annual fundraiser.", lock_version: version }
    assert_redirected_to admin_endeavor_history_path(@endeavor)
    assert_equal "The annual fundraiser.", @endeavor.history_guidances.last.body
    assert_no_difference "EndeavorHistoryGuidance.count" do
      post admin_endeavor_history_path(@endeavor), params: { operation: "guidance", guidance: "Stale", lock_version: version }
    end
    assert_match "changed", flash[:alert]
  end

  test "history manager gets Jobs without gaining minutes-run access" do
    sign_in_as(@manager)
    get admin_jobs_path
    assert_response :success
    get api_jobs_path, as: :json
    assert_response :success
    assert_empty response.parsed_body.fetch("minutes_draft_runs")
    post retry_admin_job_path(123)
    assert_redirected_to root_path
  end

  test "unpublished agenda metadata does not appear in member history or API" do
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = @organization.meeting_types.create!(name: "Meeting", position: 1, active: true)
    draft = create_dated_agenda!(organization: @organization, meeting_body: body, meeting_type: type,
      starts_at: 1.week.from_now, title: "UNPUBLISHED_CANARY")
    DatedAgendaItem.create_from_endeavor!(@endeavor, position: 1, dated_agenda: draft)
    sign_in_as(@member)
    get endeavor_path(@endeavor)
    assert_not_includes response.body, "UNPUBLISHED_CANARY"
    get api_endeavor_path(@endeavor), as: :json
    assert_response :success
    assert_empty response.parsed_body.dig("endeavor", "upcoming_agenda_ids")
    assert_not_includes response.body, "UNPUBLISHED_CANARY"
    draft.approve!(@manager)
    draft.publish!(@manager)
    get endeavor_path(@endeavor)
    assert_includes response.body, "UNPUBLISHED_CANARY"
    get api_endeavor_path(@endeavor), as: :json
    assert_includes response.parsed_body.dig("endeavor", "upcoming_agenda_ids"), draft.id
  end

  test "other organizations history is not accessible" do
    other = Organization.create!(name: "Other", unit_type: "american_legion_post", timezone: "America/Chicago")
    item = other.endeavors.create!(title: "Other work", created_by: @manager)
    sign_in_as(@manager)
    get admin_endeavor_history_path(item)
    assert_response :not_found
    get api_endeavor_history_path(item), as: :json
    assert_response :not_found
  end

  test "source reader returns only the requested current related passage or outcome" do
    _minutes, revision, source, unrelated = source_fixture
    sign_in_as(@member)
    params = { revision_id: revision.id, record_key: source["key"], unit_ids: [ source["units"].first["id"] ] }
    get source_endeavor_path(@endeavor), params: params
    assert_response :success
    assert_select ".endeavor-source-document", text: /Volunteers requested/
    assert_not_includes response.body, "Allocate the profit"
    assert_equal "private, no-store", response.headers["Cache-Control"]
    get source_endeavor_path(@endeavor), params: params.merge(unit_ids: [ source["units"].last["id"] ])
    assert_response :success
    assert_select ".history-decision", text: /Allocate the profit/
    assert_not_includes response.body, "Volunteers requested"
    get source_endeavor_path(@endeavor), params: params.merge(unit_ids: [ unrelated["units"].first["id"] ])
    assert_response :not_found
    get source_endeavor_path(@endeavor), params: params.merge(revision_id: revision.id + 100)
    assert_response :not_found
  end

  test "source reader rejects signed out cross organization and draft sources" do
    _minutes, revision, source, = source_fixture
    params = { revision_id: revision.id, record_key: source["key"], unit_ids: [ source["units"].first["id"] ] }
    get source_endeavor_path(@endeavor), params: params
    assert_redirected_to new_session_path
    sign_in_as(@member)
    other = Organization.create!(name: "Other", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.endeavors.create!(title: "Other work", created_by: @manager)
    get source_endeavor_path(foreign), params: params
    assert_response :not_found
    draft_meeting = create_meeting!(organization: @organization, meeting_body: @organization.meeting_bodies.first,
      starts_at: 1.day.ago, title: "Unattested meeting")
    draft = MeetingMinutes.create_from_meeting!(meeting: draft_meeting)
    draft.sections.first.items.create!(title: "Draft Car Show", endeavor: @endeavor, behavior_type: "report_slot", position: 1, body: "DRAFT_SOURCE_CANARY")
    draft_revision = draft.approve_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes: draft, user: @manager, action: "approve", evidence_note: "Synthetic unattested fixture."))
    draft_item = EndeavorHistory::SourceDocument.new(draft_revision).items.find { |item| item["title"] == "Draft Car Show" }
    get source_endeavor_path(@endeavor), params: { revision_id: draft_revision.id, record_key: draft_item["key"], unit_ids: [ draft_item["units"].first["id"] ] }
    assert_response :not_found
    assert_not_includes response.body, "DRAFT_SOURCE_CANARY"
  end

  test "page navigation is public while all officer controls remain capability gated" do
    sign_in_as(@member)
    get endeavor_path(@endeavor)
    assert_select "nav[aria-label='On this page']"
    assert_select ".endeavor-officer-tools", count: 0
    assert_select "details.endeavor-update", count: 0
    assert_select ".endeavor-lead .office", count: 0
    assert_select "a[href=?]", edit_endeavor_path(@endeavor), count: 0
    patch complete_endeavor_path(@endeavor)
    assert_redirected_to root_path
    assert @endeavor.reload.active?
    sign_in_as(@manager)
    get endeavor_path(@endeavor)
    assert_select ".endeavor-officer-tools a[href=?]", admin_endeavor_history_path(@endeavor)
    assert_select ".endeavor-officer-tools a[href=?]", edit_endeavor_path(@endeavor)
    assert_select "details.endeavor-update form"
  end

  private

  def source_fixture
    @manager.permission_grants.create!(capability: "approve_minutes")
    adjutant = make_user("adjutant")
    adjutant.permission_grants.create!(capability: "attest_minutes")
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: 1.week.ago, title: "Published meeting")
    minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)
    section = minutes.sections.first
    item = section.items.create!(title: "Car Show", behavior_type: "report_slot", position: 1, endeavor: @endeavor, body: "Volunteers requested")
    item.outcomes.create!(kind: "motion", text: "Allocate the profit", disposition: "adopted", position: 1)
    section.items.create!(title: "Unrelated", behavior_type: "report_slot", position: 2, body: "Unrelated account")
    revision = minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes: minutes, user: @manager, action: "approve", evidence_note: "Synthetic fixture."))
    minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes: minutes, user: adjutant, action: "attest", evidence_note: "Synthetic fixture."))
    items = EndeavorHistory::SourceDocument.new(revision).items
    [ minutes, revision, items.find { |i| i["title"] == "Car Show" }, items.find { |i| i["title"] == "Unrelated" } ]
  end

  def make_user(name, manager: false)
    person = Person.create!(first_name: name, last_name: "Example")
    user = User.create!(person: person, email_address: "#{name}@example.com", email_verified_at: Time.current)
    user.permission_grants.create!(capability: "manage_agendas") if manager
    user
  end
end
