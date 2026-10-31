require "test_helper"
require_relative "../support/endeavor_history_provider"

class EndeavorHistoriesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
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
    assert_select "h1", text: "Meeting history"
    assert_select "input[name=cost_acknowledged][required]"
    version = @endeavor.lock_version
    post admin_endeavor_history_path(@endeavor), params: { operation: "guidance", guidance: "The annual fundraiser.", lock_version: version }
    assert_redirected_to admin_endeavor_history_path(@endeavor)
    assert_equal "The annual fundraiser.", @endeavor.history_guidances.last.body
    assert_no_difference "EndeavorHistoryGuidance.count" do
      post admin_endeavor_history_path(@endeavor), params: { operation: "guidance", guidance: "Stale", lock_version: version }
    end
    assert_match "changed", flash[:alert]
  end

  test "web and API require cost acknowledgment before refresh or resume" do
    with_enabled_history do |provider|
      source_fixture
      sign_in_as(@manager)
      %w[refresh resume].each do |operation|
        @endeavor.update!(history_withdrawn: operation == "resume")
        [ nil, false, "no" ].each do |acknowledgment|
          payload = { operation: operation, lock_version: @endeavor.lock_version, cost_acknowledged: acknowledgment }
          assert_no_difference "EndeavorHistoryRun.count" do
            assert_no_difference "EndeavorHistoryEvent.count" do
              post admin_endeavor_history_path(@endeavor), params: payload
              assert_redirected_to admin_endeavor_history_path(@endeavor)
              assert_includes flash[:alert], "costs the Post money"
              post api_endeavor_history_path(@endeavor), params: payload, as: :json
              assert_response :unprocessable_entity
              assert_includes response.body, "costs the Post money"
            end
          end
          assert_equal operation == "resume", @endeavor.reload.history_withdrawn?
        end
      end
      assert_empty provider.calls
    end
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

  test "history management reports reused work separately from paid attempts" do
    run = @endeavor.history_runs.create!(manifest: { "revisions" => [] }, fingerprint: "synthetic-reuse", status: "succeeded")
    metadata = { "stage" => "discovery", "result_id" => 123 }
    @endeavor.history_events.create!(action: "reused", endeavor_history_run: run, metadata: metadata)
    sign_in_as(@manager)
    get api_endeavor_history_path(@endeavor), as: :json
    assert_response :success
    assert_empty response.parsed_body["runs"].first["steps"]
    assert_equal [ metadata ], response.parsed_body["runs"].first["reuses"]
    get admin_endeavor_history_path(@endeavor)
    assert_response :success
    assert_includes response.body, "Reused 1 previously completed step"
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
    assert_no_difference "EndeavorHistoryRun.count" do
      draft.reopen!(@manager)
      get endeavor_path(@endeavor)
      assert_not_includes response.body, "UNPUBLISHED_CANARY"
      draft.approve!(@manager)
      draft.publish!(@manager)
      get endeavor_path(@endeavor)
      assert_includes response.body, "UNPUBLISHED_CANARY"
    end
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

  test "management overview is scoped and capability gated without starting processing" do
    other = Organization.create!(name: "Other", unit_type: "american_legion_post", timezone: "America/Chicago")
    other.endeavors.create!(title: "OTHER_ORG_CANARY", created_by: @manager)
    sign_in_as(@member)
    get endeavors_path
    assert_select "a[href=?]", admin_endeavors_path, count: 0
    get admin_endeavors_path
    assert_redirected_to root_path
    sign_in_as(@manager)
    get officer_tools_path
    assert_select "a[href=?]", admin_endeavors_path
    assert_no_difference "EndeavorHistoryRun.count" do
      get admin_endeavors_path
      assert_response :success
      assert_select "h1", text: "Manage Endeavors"
      assert_select ".endeavor-management-row", count: 1
      assert_includes response.body, "No minutes yet"
      assert_not_includes response.body, "OTHER_ORG_CANARY"
      get admin_endeavors_path, params: { filter: "failed" }
      assert_select ".endeavor-management-row", count: 0
      assert_includes response.body, "No histories in this view"
      get admin_endeavors_path, params: { filter: "unknown" }
      assert_select ".endeavor-management-row", count: 1
    end
  end

  test "overview detects changed inputs and preserves published date across failure and withdrawal" do
    source_fixture
    manifest = EndeavorHistory::Sources.new(@endeavor).manifest
    run = @endeavor.history_runs.create!(status: "succeeded", manifest: manifest, fingerprint: "fixture")
    edition = @endeavor.history_editions.create!(endeavor_history_run: run, manifest: manifest, payload: { overview: [] }, sha256: "fixture")
    state = -> { EndeavorHistory::Overview.new(@organization).rows.find { |row| row[:endeavor].id == @endeavor.id } }
    assert_equal "current", state.call[:status]
    changed_signature = EndeavorHistory::Config.signature.merge("prompt_version" => "future-version")
    with_stubbed_class_method(EndeavorHistory::Config, :signature, -> { changed_signature }) do
      assert_equal "current", state.call[:status]
    end
    @endeavor.update!(summary: "New identity clarification")
    assert_equal "outdated", state.call[:status]
    @endeavor.update!(summary: manifest.dig("endeavor", "summary"))
    assert_equal "current", state.call[:status]
    @endeavor.history_runs.create!(status: "failed", manifest: manifest, fingerprint: "failure")
    assert_equal "failed", state.call[:status]
    assert_equal edition.created_at, state.call[:published_at]
    @endeavor.history_runs.create!(status: "pending", manifest: manifest, fingerprint: "pending")
    assert_equal "processing", state.call[:status]
    @endeavor.update!(history_withdrawn: true)
    assert_equal "withdrawn", state.call[:status]
    assert_empty EndeavorHistory::Overview.new(@organization).filtered("attention")
  end

  test "overview distinguishes not generated and newly available minutes" do
    assert_equal "no_minutes", EndeavorHistory::Overview.new(@organization).rows.first[:status]
    source_fixture
    assert_equal "not_generated", EndeavorHistory::Overview.new(@organization).rows.first[:status]
    assert_empty EndeavorHistory::Overview.new(@organization).filtered("attention")
    sign_in_as(@manager)
    get api_endeavor_history_path(@endeavor), as: :json
    assert_equal "not_generated", response.parsed_body["history_status"]
    assert_equal false, response.parsed_body["needs_attention"]
    get admin_endeavors_path, params: { filter: "attention" }
    assert_select ".endeavor-management-row", count: 0
  end

  test "optional archive gaps and catalog edits do not flag valid saved history for attention" do
    minutes, = source_fixture
    manifest = EndeavorHistory::Sources.new(@endeavor).manifest
    run = @endeavor.history_runs.create!(status: "succeeded", manifest: manifest, fingerprint: "fixture")
    @endeavor.history_editions.create!(endeavor_history_run: run, manifest: manifest, payload: { overview: [] }, sha256: "fixture")
    older_meeting = create_meeting!(organization: @organization, meeting_body: minutes.meeting_body,
      starts_at: 2.weeks.ago, title: "Older meeting")
    older = MeetingMinutes.create_from_meeting!(meeting: older_meeting)
    older.sections.first.items.create!(title: "Other work", behavior_type: "report_slot", position: 1, body: "Synthetic older discussion.")
    { "approve" => @manager, "attest" => User.find_by!(email_address: "adjutant@example.com") }.each do |action, actor|
      confirmation = OfficialActionConfirmation.record_external!(minutes: older, user: actor, action: action, evidence_note: "Synthetic older minutes.")
      older.public_send("#{action}_with_confirmation!", confirmation: confirmation)
    end
    @organization.endeavors.create!(title: "New work", created_by: @manager)
    row = EndeavorHistory::Overview.new(@organization).rows.find { |entry| entry[:endeavor] == @endeavor }
    assert_equal "current", row[:status]
    assert_empty EndeavorHistory::Overview.new(@organization).filtered("attention")
    sign_in_as(@manager)
    get api_endeavor_history_path(@endeavor), as: :json
    assert_equal "current", response.parsed_body["history_status"]
    assert_equal false, response.parsed_body["needs_attention"]
    @endeavor.update!(summary: "Changed identity")
    get api_endeavor_history_path(@endeavor), as: :json
    assert_equal "outdated", response.parsed_body["history_status"]
    assert_equal true, response.parsed_body["needs_attention"]
  end

  test "the signed-in handbook explains search costs and the neutral history status" do
    sign_in_as(@manager)
    get "/api", as: :json
    assert_response :success
    handbook = response.parsed_body
    inspection = handbook.fetch("common_actions").find { |action| action["name"] == "inspect_endeavor_ai_history" }
    assert_includes inspection.fetch("summary"), "history_status"
    assert_includes inspection.fetch("summary"), "needs_attention"
    assert_includes inspection.fetch("summary"), "New histories and optional archive gaps require no action"
    search = handbook.fetch("only_when_asked").find { |action| action["name"] == "manage_endeavor_ai_history" }
    assert_includes search.fetch("summary"), "Search past minutes"
    assert_includes search.fetch("summary"), "costs the Post money"
    assert_includes search.fetch("summary"), "cost_acknowledged: true"
    assert_includes search.fetch("summary"), "do not retry automatically after midnight"
    assert_equal true, JSON.parse(search.fetch("example").lines.drop(1).join)["cost_acknowledged"]
  end

  test "web guidance stays unpaid until explicit refresh and a later member request sees the edition" do
    with_enabled_history do |provider|
      source_fixture
      sign_in_as(@manager)
      post admin_endeavor_history_path(@endeavor), params: { operation: "guidance", guidance: "Preserve financial conditions.", lock_version: @endeavor.lock_version }
      assert_redirected_to admin_endeavor_history_path(@endeavor)
      assert_no_difference "EndeavorHistoryRun.count" do
        perform_enqueued_jobs { 2.times { EndeavorHistoryReconcileJob.perform_now(@organization.id) } }
      end
      assert_empty provider.calls
      post admin_endeavor_history_path(@endeavor), params: { operation: "refresh", cost_acknowledged: "1" }
      assert_redirected_to admin_endeavor_history_path(@endeavor)
      perform_enqueued_jobs(only: EndeavorHistoryJob)
      assert_equal "succeeded", @endeavor.history_runs.recent.first.status
      sign_in_as(@member)
      get endeavor_path(@endeavor)
      assert_response :success
      assert_includes response.body, "Volunteers requested"
      get api_endeavor_path(@endeavor), as: :json
      assert_response :success
      assert_includes response.body, "Volunteers requested"
    end
  end

  test "bearer scoped refresh is idempotent and explicit resume preserves delegated authority" do
    with_enabled_history do |_provider|
      minutes, = source_fixture
      token, plaintext = AgentAccessToken.issue!(user: @manager, name: "History test delegate", expires_in: 1.day)
      headers = { "Authorization" => "Bearer #{plaintext}", "Idempotency-Key" => SecureRandom.uuid }
      payload = { operation: "refresh", meeting_id: minutes.meeting_id, cost_acknowledged: true }
      assert_difference "EndeavorHistoryRun.count", 1 do
        2.times do
          post api_endeavor_history_path(@endeavor), params: payload, headers: headers, as: :json
          assert_response :accepted
        end
      end
      run = @endeavor.history_runs.recent.first
      assert_equal token.id, run.agent_access_token_id
      assert_equal minutes.meeting_id, EndeavorHistory::Requests.metadata(run)["meeting_id"]
      perform_enqueued_jobs(only: EndeavorHistoryJob)
      assert_equal "succeeded", run.reload.status
      post api_endeavor_history_path(@endeavor), params: { operation: "withdraw", lock_version: @endeavor.reload.lock_version },
        headers: headers.merge("Idempotency-Key" => SecureRandom.uuid), as: :json
      assert_response :success
      assert_predicate @endeavor.reload, :history_withdrawn?
      post api_endeavor_history_path(@endeavor), params: { operation: "resume", lock_version: @endeavor.lock_version, cost_acknowledged: true },
        headers: headers.merge("Idempotency-Key" => SecureRandom.uuid), as: :json
      assert_response :success
      perform_enqueued_jobs(only: EndeavorHistoryJob)
      resumed = @endeavor.history_runs.recent.first
      assert_equal "succeeded", resumed.status
      assert_equal token.id, resumed.agent_access_token_id
      get api_endeavor_path(@endeavor), headers: { "Authorization" => "Bearer #{plaintext}" }, as: :json
      assert_response :success
      assert_includes response.body, "Volunteers requested"
    end
  end

  private

  def with_enabled_history
    previous = ENV["ENDEAVOR_HISTORY_ENABLED"]
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "1"
    provider = EndeavorHistoryTestProvider.new
    with_stubbed_class_method(EndeavorHistory::Provider, :new, -> { provider }) { yield provider }
  ensure
    ENV["ENDEAVOR_HISTORY_ENABLED"] = previous
  end

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
