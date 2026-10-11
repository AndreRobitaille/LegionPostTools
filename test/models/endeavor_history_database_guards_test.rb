require "test_helper"

class EndeavorHistoryDatabaseGuardsTest < ActiveSupport::TestCase
  EVIDENCE_MESSAGE = "endeavor history evidence is append-only"
  RUN_MESSAGE = "endeavor history run inputs and completed results are immutable"
  RESULT_MESSAGE = "verified endeavor history results are append-only"
  CHANGES = {
    guidance: "body = 'Rewritten guidance'",
    event: "action = 'rewritten'",
    edition: "payload = '{\"rewritten\":true}'::jsonb",
    source_link: "source_ids = '[]'::jsonb",
    result: "candidate = '{\"rewritten\":true}'::jsonb"
  }.freeze

  setup do
    @old_enabled = ENV["ENDEAVOR_HISTORY_ENABLED"]
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    actor = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Adjutant"), email_address: "guard-adjutant@example.test", email_verified_at: Time.current)
    actor.permission_grants.create!(capability: "attest_minutes")
    office = organization.position_titles.create!(name: "Adjutant", display_order: 1)
    office.position_assignments.create!(person: actor.person, starts_on: 1.year.ago.to_date)
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization:, meeting_body: body, starts_at: 2.days.ago, title: "Synthetic source meeting")
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    minutes.sections.first.items.create!(title: "Community service", behavior_type: "report_slot", position: 1, body: "Synthetic volunteers reviewed the plan.")
    confirmation = OfficialActionConfirmation.record_external!(minutes:, user: actor, action: "attest", evidence_note: "Synthetic guard fixture only.")
    minutes.attest_with_confirmation!(confirmation:)
    revision = minutes.reload.member_revision
    @endeavor = organization.endeavors.create!(title: "Community service project", created_by: actor)
    @other_endeavor = organization.endeavors.create!(title: "Separate project", created_by: actor)
    @other_actor = User.create!(person: Person.create!(first_name: "Another", last_name: "Member"), email_address: "guard-other@example.test")
    @actor = actor
    @token, = AgentAccessToken.issue!(user: actor, name: "Original history request", expires_in: 1.day)
    @other_token, = AgentAccessToken.issue!(user: actor, name: "Different history request", expires_in: 1.day)
    @manifest = { "source_revision_id" => revision.id, "purpose" => "Synthetic SQL guard fixture" }
    @fingerprint = Digest::SHA256.hexdigest(JSON.generate(@manifest))
    run = new_run("succeeded")
    payload = { "overview" => [ "Synthetic verified fixture" ] }
    edition = @endeavor.history_editions.create!(endeavor_history_run: run, payload:, manifest: @manifest, sha256: Digest::SHA256.hexdigest(JSON.generate(payload)))
    source = EndeavorHistory::SourceDocument.new(revision).items.first
    @records = {
      guidance: @endeavor.history_guidances.create!(author: actor, body: "Preserve institutional continuity."),
      event: @endeavor.history_events.create!(actor:, endeavor_history_run: run, action: "published", metadata: { "synthetic" => true }),
      edition:,
      source_link: edition.source_links.create!(endeavor: @endeavor, minutes_revision: revision, record_key: source.fetch("key"), source_ids: [ source.fetch("units").first.fetch("id") ]),
      result: @endeavor.history_results.create!(endeavor_history_run: run, stage: "discovery", fingerprint: @fingerprint, input: @manifest, candidate: { "items" => [] }, verification: { "valid" => true }, configuration: { "model" => "offline fixture" })
    }
  end

  teardown { ENV["ENDEAVOR_HISTORY_ENABLED"] = @old_enabled }

  CHANGES.each do |name, change|
    %w[update delete].each do |operation|
      test "direct SQL #{operation} preserves append-only #{name}" do
        record = @records.fetch(name)
        sql = operation == "update" ? "UPDATE #{record.class.quoted_table_name} SET #{change} WHERE id = #{record.id}" : "DELETE FROM #{record.class.quoted_table_name} WHERE id = #{record.id}"
        assert_sql_refusal(record, sql, name == :result ? RESULT_MESSAGE : EVIDENCE_MESSAGE)
      end
    end
  end

  %w[pending running].each do |status|
    test "#{status} run input identity and deletion remain protected" do
      run = new_run(status)
      changes = [ "manifest = '{\"changed\":true}'::jsonb", "fingerprint = '#{'f' * 64}'", "endeavor_id = #{@other_endeavor.id}", "requested_by_id = #{@other_actor.id}", "agent_access_token_id = #{@other_token.id}", "agent_access_token_id = NULL" ]
      changes.each { |change| assert_sql_refusal(run, "UPDATE endeavor_history_runs SET #{change} WHERE id = #{run.id}", RUN_MESSAGE) }
      assert_sql_refusal(run, "DELETE FROM endeavor_history_runs WHERE id = #{run.id}", RUN_MESSAGE)
    end
  end

  %w[pending running].each do |status|
    test "automatic #{status} run cannot acquire a different delegated provenance" do
      run = new_run(status, requested_by: nil, agent_access_token_id: nil)
      assert_sql_refusal(run, "UPDATE endeavor_history_runs SET agent_access_token_id = #{@token.id} WHERE id = #{run.id}", RUN_MESSAGE)
    end
  end

  %w[succeeded failed superseded].each do |status|
    %w[update delete].each do |operation|
      test "#{status} terminal run rejects direct SQL #{operation}" do
        run = new_run(status)
        sql = operation == "update" ? "UPDATE endeavor_history_runs SET status = 'running', error_category = NULL WHERE id = #{run.id}" : "DELETE FROM endeavor_history_runs WHERE id = #{run.id}"
        assert_sql_refusal(run, sql, RUN_MESSAGE)
      end
    end
  end

  test "active progress heartbeat recovery and completion persist without rewriting inputs" do
    run = new_run("pending")
    identity = run.attributes.slice("manifest", "fingerprint", "endeavor_id", "requested_by_id", "agent_access_token_id")
    started = Time.current.change(usec: 0)
    steps = [ { "stage" => "discovery", "input_sha256" => @fingerprint, "data" => { "items" => [] }, "total_tokens" => 10 } ]
    assert_equal 1, EndeavorHistoryRun.where(id: run.id).update_all(status: "running", started_at: started, heartbeat_at: started)
    assert_predicate run.reload, :persisted?
    assert_equal "running", run.status
    assert_equal started, run.started_at
    assert_equal started, run.heartbeat_at
    assert_equal 1, EndeavorHistoryRun.where(id: run.id).update_all(steps:, heartbeat_at: started + 1.minute, error_category: "daily_budget")
    assert_equal steps, run.reload.steps
    assert_equal started + 1.minute, run.heartbeat_at
    assert_equal "daily_budget", run.error_category
    finished = started + 2.minutes
    assert_equal 1, EndeavorHistoryRun.where(id: run.id).update_all(status: "succeeded", finished_at: finished, error_category: nil)
    assert_equal "succeeded", run.reload.status
    assert_equal finished, run.finished_at
    assert_nil run.error_category
    assert_equal identity, run.attributes.slice(*identity.keys)
    assert_equal steps, run.steps
    assert_sql_refusal(run, "UPDATE endeavor_history_runs SET heartbeat_at = heartbeat_at + interval '1 minute' WHERE id = #{run.id}", RUN_MESSAGE)
  end

  private

  def new_run(status, requested_by: @actor, agent_access_token_id: @token.id)
    @endeavor.history_runs.create!(status:, manifest: @manifest, fingerprint: @fingerprint, requested_by:, agent_access_token_id:)
  end

  def assert_sql_refusal(record, sql, message)
    original = record.reload.attributes
    error = nil
    begin
      ApplicationRecord.transaction(requires_new: true) { ApplicationRecord.connection.execute(sql) }
    rescue ActiveRecord::StatementInvalid => caught
      error = caught
    end
    assert_equal original, record.class.find_by(id: record.id)&.attributes, "SQL must preserve the original row before any response/error assertion"
    assert_kind_of ActiveRecord::StatementInvalid, error
    assert_kind_of PG::RaiseException, error.cause
    assert_includes error.message, message
  end
end
