require "test_helper"
require_relative "../../support/shared_endeavor_history_provider"

class EndeavorHistorySharedDiscoveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper


  setup do
    @settings = ENV.to_h.slice("ENDEAVOR_HISTORY_ENABLED", "ENDEAVOR_HISTORY_SHARED_DISCOVERY_ENABLED", "ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET")
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "1"
    ENV["ENDEAVOR_HISTORY_SHARED_DISCOVERY_ENABLED"] = "1"
    @organization = Organization.create!(name: "Synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @manager = User.create!(person: Person.create!(first_name: "Test", last_name: "Officer"), email_address: "shared-history@example.test")
    %w[manage_agendas manage_minutes approve_minutes attest_minutes].each { |capability| @manager.permission_grants.create!(capability: capability) }
    @show = @organization.endeavors.create!(title: "Car Show", created_by: @manager)
    @picnic = @organization.endeavors.create!(title: "Picnic", status: "completed", completed_at: 1.day.ago, completed_by: @manager, created_by: @manager)
    @unrelated = @organization.endeavors.create!(title: "Newsletter", created_by: @manager)
    @withdrawn = @organization.endeavors.create!(title: "Withdrawn", history_withdrawn: true, created_by: @manager)
    @minutes = minutes("First meeting", 2.days.ago)
    @revision = attest(@minutes)
    @provider = SharedEndeavorHistoryTestProvider.new
    clear_enqueued_jobs
  end

  teardown do
    %w[ENDEAVOR_HISTORY_ENABLED ENDEAVOR_HISTORY_SHARED_DISCOVERY_ENABLED ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET].each do |key|
      ENV[key] = @settings[key]
    end
  end

  test "one shared pair publishes linked and untagged completed histories with negative coverage" do
    original = @revision.reload.attributes
    runs = [ @show, @picnic, @unrelated ].map { |endeavor| process(endeavor) }
    assert_equal [ "succeeded" ] * 3, runs.map(&:status)
    assert_equal %w[shared_discovery verify_shared_discovery summary verify_summary summary verify_summary], stages
    assert_equal 60, runs.sum(&:tokens), "Shared usage must be charged exactly once"
    assert_equal 1, EndeavorHistoryDiscovery.count
    shared = EndeavorHistoryDiscovery.first.result
    assert_equal [ @show.id, @picnic.id, @unrelated.id ], shared.candidate["endeavors"].pluck("endeavor_id")
    negative = shared.candidate["endeavors"].last["items"]
    assert negative.all? { |item| item["relevance"] == "no_match" && item["facts"].empty? }
    assert negative.flat_map { |item| item["outcomes"] }.all? { |outcome| outcome["relevant"] == false }
    assert_empty runs.last.edition.payload["overview"]
    assert_equal [ @revision.id ], runs.last.edition.manifest["revisions"].pluck("id")
    assert_equal original, @revision.reload.attributes
    assert_nil @minutes.sections.first.items.find_by!(title: "Finance report").endeavor_id
    assert_empty @withdrawn.history_runs
    runs.first(2).each do |run|
      history = EndeavorHistory::Presenter.new(run.endeavor.reload)
      assert_includes history.overview.to_json, "$100"
      assert_not_includes EndeavorHistory::Serialization.member(run.endeavor).to_json, "UNRELATED_CANARY"
      link = run.edition.source_links.first
      assert history.source(revision_id: link.minutes_revision_id, record_key: link.record_key, unit_ids: link.source_ids)[:items].any?
      if run.id != shared.endeavor_history_run_id
        assert run.endeavor.history_events.where(action: "reused").any? { |event| event.metadata["shared_result_id"] == shared.id }
      end
    end
  end

  test "negative matches still receive independent verification and failed verification blocks every consumer" do
    @provider.alter = lambda do |stage, _input, data|
      if stage == "verify_shared_discovery"
        data.replace("valid" => false, "issues" => [ { "message" => "Missed an untagged mention.", "source_ids" => [] } ])
      end
    end
    owner = process(@show)
    assert_equal "verification_failed", owner.error_category
    assert_equal %w[shared_discovery verify_shared_discovery shared_discovery verify_shared_discovery], stages
    before = @provider.calls.size
    assert_equal "shared_discovery_failed", process(@picnic).error_category
    assert_equal "shared_discovery_failed", process(@unrelated).error_category
    assert_equal before, @provider.calls.size
    assert_empty EndeavorHistoryEdition.all
  end

  test "missing duplicate and foreign targets invalid citations and ambiguity never publish" do
    input = shared_input
    candidate = @provider.call(stage: "shared_discovery", input: input, schema: EndeavorHistory::Schemas.shared_discovery).fetch("data")
    broken = [
      ->(data) { data["endeavors"].pop },
      ->(data) { data["endeavors"][1] = data["endeavors"][0].deep_dup },
      ->(data) { data["endeavors"][0]["endeavor_id"] = @withdrawn.id },
      ->(data) { data["endeavors"][0]["items"][0]["facts"][0]["source_ids"] = [ "invented" ] },
      ->(data) { data["endeavors"][0]["items"][0]["relevance"] = "ambiguous" },
      ->(data) { data["endeavors"][0]["items"][0]["outcomes"] = [] }
    ]
    broken.each do |change|
      data = candidate.deep_dup
      change.call(data)
      assert_raises(EndeavorHistory::Error) { EndeavorHistory::Validate.shared_discovery!(data, input) }
    end
    @provider.alter = ->(stage, _input, data) { data["endeavors"].pop if stage == "shared_discovery" }
    assert_equal "coverage", process(@show).error_category
    assert_empty EndeavorHistoryEdition.all
  end

  test "interrupted extraction resumes at verification and consumers cannot start their own retries" do
    @provider.alter = ->(stage, _input, _data) { raise EndeavorHistory::Error, "timeout" if stage == "verify_shared_discovery" }
    owner = process(@show)
    assert_equal "timeout", owner.error_category
    follower = process(@picnic)
    assert_equal "pending", follower.status
    assert_equal %w[shared_discovery verify_shared_discovery], stages
    assert_empty follower.steps
    @provider.alter = nil
    travel 16.minutes do
      retry_run = EndeavorHistory::Processing.request(@show, retry_run: owner)
      EndeavorHistory::Processing.new(retry_run, provider: @provider).call
      assert_equal "succeeded", retry_run.reload.status
      assert_equal 1, stages.count("shared_discovery"), "A saved extraction must survive an interrupted verifier"
      assert owner.reload.steps.last["reserved"], "Unknown timeout costs remain reserved"
      EndeavorHistory::Processing.new(follower.reload, provider: @provider).call
      assert_equal "succeeded", follower.reload.status
      assert_equal 2, stages.count("verify_shared_discovery")
      assert_equal 1, EndeavorHistoryDiscovery.count
    end
  end

  test "daily budget failure cannot fan out or restart the next day" do
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = "1"
    owner = process(@show)
    assert_equal "daily_budget", owner.error_category
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = "500000"
    assert_equal "shared_discovery_failed", process(@picnic).error_category
    travel 1.day do
      assert_no_difference "EndeavorHistoryRun.count" do
        EndeavorHistoryReconcileJob.perform_now(@organization.id)
      end
      assert_equal "shared_discovery_failed", process(@unrelated).error_category
    end
    assert_empty @provider.calls
  end

  test "transport retries are bounded across all consumers and keep the saved extraction" do
    @provider.alter = ->(stage, _input, _data) { raise EndeavorHistory::Error, "provider_error" if stage == "verify_shared_discovery" }
    owner = process(@show)
    follower = process(@picnic)
    assert_equal "pending", follower.status
    2.times do |index|
      travel (index + 1) * 16.minutes do
        owner = EndeavorHistory::Processing.request(@show, retry_run: owner)
        EndeavorHistory::Processing.new(owner, provider: @provider).call
        assert_equal "provider_error", owner.reload.error_category
      end
    end
    assert_equal 1, stages.count("shared_discovery")
    assert_equal 3, stages.count("verify_shared_discovery")
    EndeavorHistory::Processing.new(follower.reload, provider: @provider).call
    assert_equal "shared_discovery_failed", follower.reload.error_category
    assert_equal "shared_discovery_failed", process(@unrelated).error_category
    travel 1.day do
      assert_no_difference "EndeavorHistoryRun.count" do
        EndeavorHistoryReconcileJob.perform_now(@organization.id)
      end
    end
    assert_equal 4, @provider.calls.size
  end

  test "accepted shared input and result provenance are protected by SQL and uniqueness" do
    process(@show)
    discovery = EndeavorHistoryDiscovery.first
    original = discovery.attributes
    statements = [
      "UPDATE endeavor_history_discoveries SET input = '{}'::jsonb WHERE id = #{discovery.id}",
      "UPDATE endeavor_history_discoveries SET result_id = NULL WHERE id = #{discovery.id}",
      "DELETE FROM endeavor_history_discoveries WHERE id = #{discovery.id}",
      "UPDATE endeavor_history_results SET candidate = '{}'::jsonb WHERE id = #{discovery.result_id}"
    ]
    statements.each do |sql|
      assert_raises(ActiveRecord::StatementInvalid) do
        ApplicationRecord.transaction(requires_new: true) { ApplicationRecord.connection.execute(sql) }
      end
      assert_equal original, discovery.reload.attributes
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      ApplicationRecord.transaction(requires_new: true) do
        EndeavorHistoryDiscovery.create!(organization: @organization, fingerprint: discovery.fingerprint, input: discovery.input)
      end
    end
    assert_equal "succeeded", process(@picnic).status
    assert_equal 1, stages.count("shared_discovery")
  end

  test "unaccepted coordination rows protect their input while allowing recovery progress" do
    @provider.alter = ->(stage, _input, _data) { raise EndeavorHistory::Error, "timeout" if stage == "shared_discovery" }
    process(@show)
    discovery = EndeavorHistoryDiscovery.first
    original = discovery.attributes
    assert_raises(ActiveRecord::StatementInvalid) do
      ApplicationRecord.transaction(requires_new: true) do
        discovery.update_columns(input: { "changed" => true })
      end
    end
    assert_equal original, discovery.reload.attributes
    discovery.update!(error_category: "worker_stalled")
    assert_equal "worker_stalled", discovery.reload.error_category
  end

  test "unmatched later minutes reuse prose without new summary calls" do
    previous = process(@show).edition
    later = minutes("Unmatched meeting", 1.day.ago)
    later.sections.first.items.destroy_all
    later.sections.first.items.create!(title: "Unrelated report", position: 1, behavior_type: "report_slot", body: "Membership renewals only.")
    attest(later)
    @provider.calls.clear
    current = process(@show).edition
    assert_equal %w[shared_discovery verify_shared_discovery], stages
    assert_equal previous.payload["overview"], current.payload["overview"]
    assert_equal previous.payload["meetings"], current.payload["meetings"]
  end

  test "concurrent consumer waits on the database lock and makes no provider calls" do
    follower = new_run(@picnic)
    waited = false
    @provider.alter = lambda do |stage, input, _data|
      next unless stage == "shared_discovery"
      consumer = EndeavorHistory::SharedDiscovery.new(follower, input)
      waited = Thread.new do
        begin
          consumer.fetch { flunk "Concurrent consumer must not become a paid producer" }
          false
        rescue EndeavorHistory::SharedDiscovery::Waiting
          true
        end
      end.value
    end
    assert_equal "succeeded", process(@show).status
    assert waited
    @provider.alter = nil
    EndeavorHistory::Processing.new(follower, provider: @provider).call
    assert_equal "succeeded", follower.reload.status
    assert_equal 1, stages.count("shared_discovery")
  end

  test "changed peer guidance and withdrawal stop shared work before a paid call" do
    run = new_run(@show)
    EndeavorHistory::Manage.change(@picnic, user: @manager, action: "guidance", lock_version: @picnic.lock_version, guidance: "Only last year's Picnic.")
    EndeavorHistory::Processing.new(run, provider: @provider).call
    assert_equal "superseded", run.reload.status
    assert_empty @provider.calls
    run = new_run(@unrelated)
    EndeavorHistory::Manage.change(@show, user: @manager, action: "withdraw", lock_version: @show.lock_version)
    EndeavorHistory::Processing.new(run, provider: @provider).call
    assert_equal "superseded", run.reload.status
    assert_empty @provider.calls
  end

  test "source changes during extraction prevent verification and publication" do
    @provider.alter = lambda do |stage, _input, _data|
      next unless stage == "shared_discovery"
      reopen(@minutes)
      @minutes.sections.first.items.first.update!(body: "Corrected source.")
      attest(@minutes)
    end
    assert_equal "superseded", process(@show).status
    assert_equal [ "shared_discovery" ], stages
    assert_empty EndeavorHistoryEdition.all
  end

  test "new attestation reuses old accounts and corrections replace only their source" do
    first = process(@show).edition
    process(@picnic)
    second_minutes = minutes("Later meeting", 1.day.ago)
    second_revision = attest(second_minutes)
    updated = process(@show).edition
    process(@picnic)
    assert_equal 2, stages.count("shared_discovery")
    assert_equal first.payload["meetings"].first, updated.payload["meetings"].find { |entry| entry["revision_id"] == @revision.id }
    reopen(@minutes)
    @minutes.sections.first.items.find_by!(title: "Finance report").update!(body: "The Car Show and Picnic each received $200.")
    replacement = attest(@minutes)
    assert_empty EndeavorHistory::Presenter.new(@show.reload).overview
    corrected = process(@show).edition
    process(@picnic)
    assert_equal 3, stages.count("shared_discovery")
    assert_equal [ replacement.id, second_revision.id ].sort, corrected.manifest["revisions"].pluck("id").sort
    assert_equal updated.payload["meetings"].find { |entry| entry["revision_id"] == second_revision.id },
      corrected.payload["meetings"].find { |entry| entry["revision_id"] == second_revision.id }
    assert_not_includes corrected.payload["evidence"].pluck("revision_id"), @revision.id
    assert_includes corrected.payload.to_json, "$200"
  end

  test "turning off shared work stops queued groups without paid target fallback" do
    run = new_run(@show)
    ENV["ENDEAVOR_HISTORY_SHARED_DISCOVERY_ENABLED"] = "0"
    EndeavorHistory::Processing.new(run, provider: @provider).call
    assert_equal "disabled", run.reload.error_category
    assert_empty @provider.calls
  end

  test "manual searches retain target scope and revoked authority blocks them" do
    run = EndeavorHistory::Processing.request(@show, requester: @manager, force: true, meeting_id: @minutes.meeting_id)
    EndeavorHistory::Processing.new(run, provider: @provider).call
    assert_equal "succeeded", run.reload.status
    assert_equal %w[discovery verify_discovery summary verify_summary], stages
    assert_empty EndeavorHistoryDiscovery.all
    denied = EndeavorHistory::Processing.request(@picnic, requester: @manager, force: true)
    @manager.permission_grants.find_by!(capability: "manage_agendas").destroy!
    before = @provider.calls.size
    EndeavorHistory::Processing.new(denied, provider: @provider).call
    assert_equal "forbidden", denied.reload.error_category
    assert_equal before, @provider.calls.size
  end

  private

  def stages = @provider.calls.map(&:first)

  def new_run(endeavor)
    EndeavorHistory::Processing.request(endeavor, attestation_request: EndeavorHistory::Requests.latest(endeavor))
  end

  def process(endeavor)
    run = new_run(endeavor)
    EndeavorHistory::Processing.new(run, provider: @provider).call
    run.reload
  end

  def shared_input
    group = EndeavorHistory::Requests.latest(@show).metadata.fetch("shared_discovery")
    { "endeavors" => group.fetch("targets"), "source" => EndeavorHistory::SourceDocument.new(@revision).payload }
  end

  def minutes(title, starts_at)
    meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: starts_at, title: title)
    minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)
    section = minutes.sections.first
    item = section.items.create!(title: "Finance report", position: 1, behavior_type: "report_slot", body: "The Car Show and Picnic each received $100.")
    item.outcomes.create!(kind: "motion", position: 1, text: "Allocate $100 to the Car Show and Picnic.", disposition: "adopted")
    section.items.create!(title: "Car Show update", position: 2, behavior_type: "report_slot", endeavor: @show, body: "The Car Show still needs volunteers.")
    section.items.create!(title: "Unrelated report", position: 3, behavior_type: "report_slot", body: "UNRELATED_CANARY membership renewal.")
    minutes
  end

  def attest(minutes)
    confirmation = OfficialActionConfirmation.record_external!(minutes: minutes, user: @manager, action: "attest", evidence_note: "Synthetic shared discovery test.")
    minutes.attest_with_confirmation!(confirmation: confirmation)
    minutes.reload.current_revision
  end

  def reopen(minutes)
    confirmation = OfficialActionConfirmation.record_external!(minutes: minutes, user: @manager, action: "reopen", evidence_note: "Synthetic correction.", action_payload: { "reason" => "Correct the financial report." })
    minutes.reopen_with_confirmation!(confirmation: confirmation)
  end
end
