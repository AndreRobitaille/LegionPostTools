require_relative "history_test"

class EndeavorHistoryTest
  test "attestation recovery retains both sources when commit order differs from journal IDs" do
    first = add_meeting
    second = add_meeting(body: "More volunteers confirmed.")
    manifest = EndeavorHistory::Sources.new(@endeavor).manifest
    # Concurrent transactions allocate journal IDs before commit. The lower-ID
    # transaction can commit last, after a higher-ID request has been dispatched.
    late_request = @endeavor.history_events.create!(action: "attestation_requested",
      metadata: { "revision_id" => second.id, "manifest" => manifest.except("configuration").merge("revisions" => manifest["revisions"].select { |entry| entry["id"] == second.id }) })
    early_manifest = manifest.merge("revisions" => manifest["revisions"].select { |entry| entry["id"] == first.id })
    early_request = @endeavor.history_events.create!(action: "attestation_requested",
      metadata: { "revision_id" => first.id, "manifest" => early_manifest.except("configuration") })
    superseded = @endeavor.history_runs.create!(manifest: early_manifest, fingerprint: EndeavorHistory::Sources.digest(early_manifest),
      status: "superseded", error_category: "source_changed", finished_at: Time.current)
    @endeavor.history_events.create!(action: "requested", endeavor_history_run: superseded,
      metadata: { "trigger" => "attestation", "attestation_request_id" => early_request.id })
    assert_equal late_request, EndeavorHistory::Requests.pending(@endeavor)
    reconcile_and_process
    run = @endeavor.history_runs.recent.first
    assert_equal "succeeded", run.status
    assert_equal [ first.id, second.id ], run.edition.manifest["revisions"].pluck("id")
    assert_equal [ first.id, second.id ], @provider.calls.select { |stage, _| stage == "discovery" }.map { |_, input| input["source"]["revision_id"] }
  end

  test "queued attestation from before spend control cannot search unrequested archive revisions" do
    minutes = attest_later_minutes
    request = EndeavorHistory::Requests.latest(@endeavor)
    manifest = EndeavorHistory::Sources.new(@endeavor).manifest
    run = @endeavor.history_runs.create!(manifest: manifest, fingerprint: EndeavorHistory::Sources.digest(manifest))
    @endeavor.history_events.create!(action: "requested", endeavor_history_run: run,
      metadata: { "trigger" => "attestation", "attestation_request_id" => request.id })
    clear_enqueued_jobs
    with_offline_history_provider { EndeavorHistoryJob.perform_now(run.id) }
    assert_latest_history(minutes)
    assert_equal [ minutes.member_revision.id ], @provider.calls.select { |stage, _| stage == "discovery" }.map { |_, input| input["source"]["revision_id"] }
    assert_equal [ minutes.member_revision.id ], run.reload.edition.manifest["revisions"].pluck("id")
  end

  test "scoped refresh leaves unprocessed archive untouched and full refresh can explicitly search it" do
    later = add_meeting
    run = EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true, meeting_id: later.meeting_minutes.meeting_id)
    with_offline_history_provider { perform_enqueued_jobs(only: EndeavorHistoryJob) }
    assert_equal "succeeded", run.reload.status
    assert_equal [ later.id ], @provider.calls.select { |stage, _| stage == "discovery" }.map { |_, input| input["source"]["revision_id"] }
    assert_equal [ later.id ], run.edition.manifest["revisions"].pluck("id")
    @provider.calls.clear
    full = EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true)
    with_offline_history_provider { perform_enqueued_jobs(only: EndeavorHistoryJob) }
    assert_equal "succeeded", full.reload.status
    assert_equal [ @revision.id, later.id ], full.edition.manifest["revisions"].pluck("id")
    assert_equal [ @revision.id, later.id ], @provider.calls.select { |stage, _| stage == "discovery" }.map { |_, input| input["source"]["revision_id"] }
  end

  test "budget failure stays stopped across midnight until a new explicit request" do
    previous_budget = ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"]
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = "1"
    minutes = attest_later_minutes
    reconcile_and_process
    failed = @endeavor.history_runs.recent.first
    assert_equal "daily_budget", failed.error_category
    assert_empty @provider.calls
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = previous_budget

    [ 1.day, 3.days ].each do |delay|
      travel delay do
        assert_no_difference "EndeavorHistoryRun.count" do
          2.times { reconcile_and_process }
        end
        assert_nil EndeavorHistory::Processing.request(@endeavor, retry_run: failed)
        assert_empty @provider.calls
      end
    end
    EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true)
    with_offline_history_provider { perform_enqueued_jobs(only: EndeavorHistoryJob) }
    assert_latest_history(minutes)
  ensure
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = previous_budget
  end

  test "attestation checks only requested minutes and does not search an untouched archive" do
    untouched = @revision
    first = attest_later_minutes
    second = attest_later_minutes(body: "More volunteers confirmed.")
    reconcile_and_process
    run = @endeavor.history_runs.recent.first
    assert_equal "succeeded", run.status
    assert_equal [ first.member_revision.id, second.member_revision.id ],
      @provider.calls.select { |stage, _| stage == "discovery" }.map { |_, input| input["source"]["revision_id"] }
    assert_equal [ first.member_revision.id, second.member_revision.id ].sort, run.edition.manifest["revisions"].pluck("id").sort
    assert_not_includes run.edition.payload["evidence"].pluck("revision_id"), untouched.id
    assert EndeavorHistory::Presenter.new(@endeavor.reload).newer_minutes?
    assert_equal untouched.sha256, untouched.reload.sha256
  end

  test "attestation after catalog growth retains historical evidence without auditing it again" do
    previous = process.edition
    new_endeavor = @organization.endeavors.create!(title: "New work never discussed", created_by: @manager)
    minutes = attest_later_minutes
    @provider.calls.clear
    reconcile_and_process
    original_run = @endeavor.history_runs.recent.first
    new_run = new_endeavor.history_runs.recent.first
    discoveries = @provider.calls.select { |stage, _| %w[discovery verify_discovery].include?(stage) }
    assert_equal [ minutes.member_revision.id ], discoveries.map { |_, input| input["source"]["revision_id"] }.uniq
    assert_equal 4, discoveries.size
    assert_equal previous.payload["meetings"].first, original_run.edition.payload["meetings"].first
    assert_equal [ minutes.member_revision.id ], new_run.edition.payload["evidence"].pluck("revision_id")
    assert @endeavor.history_events.where(action: "reused", endeavor_history_run: original_run).any? { |event| event.metadata["edition_id"] == previous.id }
    calls = @provider.calls.length
    assert_no_difference "EndeavorHistoryRun.count" do
      travel(1.day) { reconcile_and_process }
    end
    assert_equal calls, @provider.calls.length
  end

  test "trigger recovery covers a newer attestation after an older pending run is superseded" do
    original = EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true)
    clear_enqueued_jobs
    minutes = attest_later_minutes
    perform_enqueued_jobs(only: EndeavorHistoryRefreshJob)
    assert_equal [ original.id ], @endeavor.history_runs.pluck(:id)
    EndeavorHistory::Processing.new(original, provider: @provider).call
    assert_equal "superseded", original.reload.status
    assert_empty @provider.calls
    reconcile_and_process
    assert_latest_history(minutes)
    calls = @provider.calls.length
    2.times { reconcile_and_process }
    assert_equal calls, @provider.calls.length
    assert_equal 2, @endeavor.history_runs.count
  end

  test "trigger recovery retains a new attestation arriving during a provider stage" do
    minutes = nil
    @provider.alter = lambda do |stage, _input, _data|
      if stage == "discovery" && !minutes
        minutes = attest_later_minutes
      end
    end
    original = EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true)
    with_offline_history_provider { perform_enqueued_jobs(only: EndeavorHistoryJob) }
    assert_equal "superseded", original.reload.status
    assert_nil original.edition
    @provider.alter = nil
    reconcile_and_process
    assert_latest_history(minutes)
  end

  %w[refusal exception].each do |failure|
    test "trigger recovery survives initial queue #{failure} after attestation commits" do
      original_enqueue = EndeavorHistoryRefreshJob.method(:perform_later)
      begin
        EndeavorHistoryRefreshJob.define_singleton_method(:perform_later) do |*|
          raise ActiveJob::EnqueueError, "Synthetic queue outage" if failure == "exception"
          false
        end
        minutes = attest_later_minutes
      ensure
        EndeavorHistoryRefreshJob.define_singleton_method(:perform_later, original_enqueue)
      end
      assert minutes.reload.member_revision.attestation
      assert_empty @endeavor.history_runs
      clear_enqueued_jobs
      reconcile_and_process
      assert_latest_history(minutes)
    end
  end

  %w[catalog guidance source].each do |drift|
    test "trigger recovery defers a scoped manual retry after #{drift} drift without spending" do
      token, = AgentAccessToken.issue!(user: @manager, name: "Scoped review delegate", expires_in: 1.day)
      original = Current.set(agent_access_token: token) do
        EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true, meeting_id: @meeting.id)
      end
      original.update!(status: "failed", error_category: "provider_error", finished_at: 16.minutes.ago)
      case drift
      when "catalog"
        @organization.endeavors.create!(title: "Other work", created_by: @manager)
      when "guidance"
        EndeavorHistory::Manage.change(@endeavor.reload, user: @manager, action: "guidance",
          lock_version: @endeavor.lock_version, guidance: "Preserve financial conditions.")
      when "source"
        add_meeting # Synthetic attestation while automatic processing is disabled.
      end
      clear_enqueued_jobs
      assert_no_difference "EndeavorHistoryRun.count" do
        2.times { reconcile_and_process }
      end
      assert_empty @provider.calls
      assert_equal [ @manager.id, token.id ], original.reload.attributes.values_at("requested_by_id", "agent_access_token_id")
      metadata = EndeavorHistory::Requests.metadata(original)
      assert_equal @meeting.id, metadata["meeting_id"]
      assert_equal true, metadata["refresh"]
      assert_equal 1, @endeavor.history_events.where(action: "recovery_deferred", endeavor_history_run: original).count
    end
  end

  test "trigger recovery retries a scoped manual failure using its original authority and cached stages" do
    automatic_process
    token, = AgentAccessToken.issue!(user: @manager, name: "Scoped retry delegate", expires_in: 3.days)
    @provider.alter = ->(stage, _input, _data) { raise EndeavorHistory::Error, "provider_error" if stage == "summary" }
    original = Current.set(agent_access_token: token) do
      EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true, meeting_id: @meeting.id)
    end
    with_offline_history_provider { perform_enqueued_jobs(only: EndeavorHistoryJob) }
    assert_equal "provider_error", original.reload.error_category
    @provider.alter = nil
    @provider.calls.clear
    travel 16.minutes do
      reconcile_and_process
      recovered = @endeavor.history_runs.recent.first
      assert_equal "succeeded", recovered.status
      assert_equal [ @manager.id, token.id ], recovered.attributes.values_at("requested_by_id", "agent_access_token_id")
      metadata = EndeavorHistory::Requests.metadata(recovered)
      assert_equal @meeting.id, metadata["meeting_id"]
      assert_equal original.id, metadata["refresh_id"]
      assert_equal original.id, metadata["retry_root_id"]
      assert_equal %w[summary verify_summary], @provider.calls.map(&:first)
    end
  end

  %w[capability token disabled].each do |revocation|
    test "trigger recovery denies provider access after manual #{revocation} revocation" do
      token, = AgentAccessToken.issue!(user: @manager, name: "Revoked review delegate", expires_in: 1.day)
      original = Current.set(agent_access_token: token) do
        EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true, meeting_id: @meeting.id)
      end
      original.update!(status: "failed", error_category: "timeout", finished_at: 16.minutes.ago)
      case revocation
      when "capability" then @manager.permission_grants.find_by!(capability: "manage_agendas").destroy!
      when "token" then token.update!(revoked_at: Time.current)
      when "disabled" then @manager.update!(disabled_at: Time.current)
      end
      clear_enqueued_jobs
      reconcile_and_process
      assert_empty @provider.calls
      assert_equal "forbidden", @endeavor.history_runs.recent.first.error_category
      assert_empty @endeavor.history_editions
    end
  end

  test "trigger journal does not backfill old attestations or later-created endeavors" do
    clear_enqueued_jobs
    assert_no_difference "EndeavorHistoryRun.count" do
      2.times { reconcile_and_process }
      EndeavorHistoryRefreshJob.perform_now(@endeavor.id) # Pre-release queued job.
    end
    minutes = attest_later_minutes
    reconcile_and_process
    assert_latest_history(minutes)
    @provider.calls.clear
    added = @organization.endeavors.create!(title: "New future work", created_by: @manager)
    clear_enqueued_jobs
    assert_no_difference "EndeavorHistoryRun.count" do
      2.times { reconcile_and_process }
    end
    assert_empty added.history_events
    assert_empty @provider.calls
    next_minutes = attest_later_minutes(body: "Later work discussed.")
    reconcile_and_process
    assert_equal "succeeded", added.history_runs.recent.first.status
    assert_includes added.history_runs.recent.first.manifest["revisions"].pluck("id"), next_minutes.member_revision.id
  end

  test "trigger journal rolls back with the attestation and creates no request while disabled" do
    minutes = nil
    assert_no_difference "EndeavorHistoryEvent.where(action: 'attestation_requested').count" do
      MeetingMinutes.transaction(requires_new: true) do
        minutes = attest_later_minutes
        raise ActiveRecord::Rollback
      end
    end
    assert_not MeetingMinutes.exists?(minutes.id)
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    assert_no_difference "EndeavorHistoryEvent.where(action: 'attestation_requested').count" do
      attest_later_minutes
    end
  end

  %w[catalog guidance].each do |drift|
    test "trigger journal defers unstarted attestation work after #{drift} changes" do
      attest_later_minutes
      if drift == "catalog"
        @endeavor.update!(summary: "Changed matching context")
      else
        EndeavorHistory::Manage.change(@endeavor.reload, user: @manager, action: "guidance",
          lock_version: @endeavor.lock_version, guidance: "Changed context")
      end
      assert_no_difference "EndeavorHistoryRun.count" do
        2.times { reconcile_and_process }
      end
      assert_empty @provider.calls
    end
  end

  test "trigger journal rejects stale foreign and duplicate refresh deliveries" do
    first = attest_later_minutes
    stale_request = EndeavorHistory::Requests.latest(@endeavor)
    latest = attest_later_minutes(body: "Latest volunteer plan.")
    request = EndeavorHistory::Requests.latest(@endeavor)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.endeavors.create!(title: "Other work", created_by: @manager)
    assert_no_difference "EndeavorHistoryRun.count" do
      EndeavorHistoryRefreshJob.perform_now(foreign.id, request.id)
      EndeavorHistoryRefreshJob.perform_now(@endeavor.id, stale_request.id)
    end
    assert_not_equal first.member_revision.id, latest.member_revision.id
    reconcile_and_process
    assert_latest_history(latest)
    @provider.calls.clear
    with_offline_history_provider do
      perform_enqueued_jobs(only: EndeavorHistoryJob) do
        2.times { EndeavorHistoryRefreshJob.perform_now(@endeavor.id, request.id) }
      end
    end
    assert_equal 1, @endeavor.history_runs.count
    assert_empty @provider.calls
  end

  test "trigger rollout refuses unproven legacy runs without losing a new attestation" do
    manifest = EndeavorHistory::Sources.new(@endeavor).manifest
    legacy = @endeavor.history_runs.create!(manifest: manifest, fingerprint: EndeavorHistory::Sources.digest(manifest))
    with_offline_history_provider { EndeavorHistoryJob.perform_now(legacy.id) }
    assert_equal "unproven_request", legacy.reload.error_category
    assert_empty @provider.calls
    minutes = attest_later_minutes
    reconcile_and_process
    assert_latest_history(minutes)
  end

  test "trigger rollout does not let an unproven run with current inputs consume a journal request" do
    minutes = attest_later_minutes
    manifest = EndeavorHistory::Sources.new(@endeavor).manifest
    legacy = @endeavor.history_runs.create!(manifest: manifest, fingerprint: EndeavorHistory::Sources.digest(manifest))
    reconcile_and_process
    assert_equal "unproven_request", legacy.reload.error_category
    assert_latest_history(minutes)
  end

  %w[refusal exception].each do |failure|
    test "trigger recovery survives worker queue #{failure} after the run is recorded" do
      minutes = attest_later_minutes
      original_enqueue = EndeavorHistoryJob.method(:perform_later)
      begin
        EndeavorHistoryJob.define_singleton_method(:perform_later) do |*|
          raise ActiveJob::EnqueueError, "Synthetic worker queue outage" if failure == "exception"
          false
        end
        perform_enqueued_jobs(only: EndeavorHistoryRefreshJob)
      ensure
        EndeavorHistoryJob.define_singleton_method(:perform_later, original_enqueue)
      end
      original = @endeavor.history_runs.recent.first
      assert_equal "queue_error", original.error_category
      assert_empty @provider.calls
      travel(16.minutes) { reconcile_and_process }
      assert_latest_history(minutes)
      assert_equal original.id, EndeavorHistory::Requests.retry_root(@endeavor.history_runs.recent.first)
    end
  end

  test "trigger recovery rejects a stale retry selection without bypassing the newest attempt delay" do
    original = EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true)
    original.update!(status: "failed", error_category: "timeout", finished_at: 16.minutes.ago)
    second = EndeavorHistory::Processing.request(@endeavor, retry_run: original)
    second.update!(status: "failed", error_category: "timeout", finished_at: Time.current)
    assert_no_difference "EndeavorHistoryRun.count" do
      assert_equal second, EndeavorHistory::Processing.request(@endeavor, retry_run: original)
      reconcile_and_process
    end
    assert_empty @provider.calls
  end

  test "trigger journal processes PEC attestation through publication and later member reads" do
    @body = @organization.meeting_bodies.create!(name: "Post Executive Committee", slug: "synthetic-governing-body")
    minutes = attest_later_minutes
    reconcile_and_process
    assert_latest_history(minutes)
    assert_equal @body.id, minutes.meeting_body_id
  end

  test "trigger journal keeps semantic failure terminal until explicit refresh" do
    minutes = attest_later_minutes
    @provider.alter = lambda do |stage, _input, data|
      if stage == "verify_discovery"
        data["valid"] = false
        data["issues"] = [ { "message" => "Synthetic semantic failure", "source_ids" => [] } ]
      end
    end
    reconcile_and_process
    failed = @endeavor.history_runs.recent.first
    assert_equal "verification_failed", failed.error_category
    calls = @provider.calls.length
    assert_no_difference "EndeavorHistoryRun.count" do
      travel(1.day) { 2.times { reconcile_and_process } }
    end
    assert_equal calls, @provider.calls.length
    assert_empty @endeavor.history_editions
    @provider.alter = nil
    # Unchanged failed source checks remain evidence; an explicit refresh revisits them.
    EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true)
    with_offline_history_provider { perform_enqueued_jobs(only: EndeavorHistoryJob) }
    assert_latest_history(minutes)
  end

  test "trigger journal commits attestation independently of broken provider configuration" do
    previous = ENV["OPENAI_ENDEAVOR_DISCOVERY_REASONING"]
    ENV["OPENAI_ENDEAVOR_DISCOVERY_REASONING"] = "invalid-setting"
    minutes = attest_later_minutes
    assert minutes.member_revision.attestation
    assert EndeavorHistory::Requests.pending(@endeavor)
    assert_empty @provider.calls
    ENV["OPENAI_ENDEAVOR_DISCOVERY_REASONING"] = previous
    reconcile_and_process
    assert_latest_history(minutes)
  ensure
    ENV["OPENAI_ENDEAVOR_DISCOVERY_REASONING"] = previous
  end

  [ 2, 3 ].each do |attempt_count|
    test "trigger recovery preserves the legacy manual retry chain after #{attempt_count} attempts" do
      manifest = EndeavorHistory::Sources.new(@endeavor).manifest
      root = nil
      attempt_count.times do
        run = @endeavor.history_runs.create!(manifest: manifest, fingerprint: EndeavorHistory::Sources.digest(manifest),
          requested_by: @manager, status: "failed", error_category: "timeout", finished_at: 16.minutes.ago)
        root ||= run.id
        @endeavor.history_events.create!(action: "requested", actor: @manager, endeavor_history_run: run,
          metadata: { "force" => true, "refresh" => true, "refresh_id" => root, "meeting_id" => @meeting.id })
      end
      legacy = @endeavor.history_runs.recent.first
      assert_equal root, EndeavorHistory::Requests.retry_root(legacy)
      assert_equal attempt_count, EndeavorHistory::Requests.attempts(legacy)
      assert_difference "EndeavorHistoryRun.count", attempt_count == 2 ? 1 : 0 do
        reconcile_and_process
      end
      if attempt_count == 2
        recovered = @endeavor.history_runs.recent.first
        assert_equal "succeeded", recovered.status
        assert_equal @manager.id, recovered.requested_by_id
        request = EndeavorHistory::Requests.metadata(recovered)
        assert_equal root, request["refresh_id"]
        assert_equal root, request["retry_root_id"]
        assert_equal @meeting.id, request["meeting_id"]
      else
        assert_empty @provider.calls
      end
    end
  end

  private

  def attest_later_minutes(body: "Latest volunteers confirmed.")
    meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.hour.ago, title: "Later meeting")
    minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)
    minutes.sections.first.items.create!(title: "Car Show", behavior_type: "report_slot", position: 1, body: body)
    attest(minutes)
    minutes.reload
  end

  def with_offline_history_provider
    original = EndeavorHistory::Provider.method(:new)
    provider = @provider
    EndeavorHistory::Provider.define_singleton_method(:new) { provider }
    yield
  ensure
    EndeavorHistory::Provider.define_singleton_method(:new, original)
  end

  def reconcile_and_process
    with_offline_history_provider do
      perform_enqueued_jobs(only: [ EndeavorHistoryRefreshJob, EndeavorHistoryJob ]) do
        EndeavorHistoryReconcileJob.perform_now(@organization.id)
      end
      perform_enqueued_jobs(only: [ EndeavorHistoryRefreshJob, EndeavorHistoryJob ])
    end
  end

  def assert_latest_history(minutes)
    run = @endeavor.history_runs.recent.first
    assert run, "Expected recoverable work for the attestation"
    assert_equal "succeeded", run.status
    assert_includes run.edition.payload["meetings"].pluck("revision_id"), minutes.member_revision.id
    serialized = EndeavorHistory::Serialization.member(@endeavor.reload).to_json
    assert_includes serialized, "volunteer"
    assert_equal serialized, EndeavorHistory::Serialization.member(Endeavor.find(@endeavor.id)).to_json
  end
end
