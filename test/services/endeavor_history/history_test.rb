require "test_helper"

class EndeavorHistoryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class FakeProvider
    attr_reader :calls
    attr_accessor :alter

    def initialize
      @calls = []
    end

    def call(stage:, input:, schema:)
      @calls << [ stage, input ]
      data = case stage
      when "discovery"
        { "items" => input.fetch("source").fetch("items").map do |item|
          units = item.fetch("units").reject { |unit| unit["kind"] == "title" }
          relevant = item["title"] != "Unrelated report"
          { "key" => item["key"], "relevance" => relevant ? "related" : "no_match", "reason" => "Source matches the named event.",
            "facts" => relevant ? units.map { |unit| { "text" => unit["text"], "kind" => "report", "source_ids" => [ unit["id"] ] } } : [],
            "outcomes" => units.select { |unit| unit["kind"] == "outcome" }.map { |unit| { "source_id" => unit["id"], "relevant" => relevant, "reason" => "Recorded event decision." } } }
        end }
      when "summary"
        meetings = input.fetch("meetings").select { |meeting| meeting["facts"].any? && (!input["account_revision_ids"] || input["account_revision_ids"].include?(meeting["revision_id"])) }.map do |meeting|
          { "revision_id" => meeting["revision_id"], "headline" => { "text" => "Volunteer needs and recorded decisions", "fact_ids" => [ meeting["facts"].first["id"] ] },
            "decision_titles" => meeting["items"].flat_map { |item| item["units"].select { |unit| unit["kind"] == "outcome" }.map { |unit| { "source_id" => unit["id"], "text" => "Fund allocation" } } },
            "claims" => meeting["facts"].map { |fact| { "text" => fact["text"], "fact_ids" => [ fact["id"] ] } } }
        end
        { "overview" => input["meetings"].flat_map { |meeting| meeting["facts"].map { |fact| { "text" => fact["text"], "fact_ids" => [ fact["id"] ] } } }.first(2), "meetings" => meetings }
      else
        { "valid" => true, "issues" => [] }
      end
      @alter&.call(stage, input, data)
      { "data" => data, "total_tokens" => 10, "input_tokens" => 5, "output_tokens" => 5, "model" => "offline-fake" }
    end
  end

  setup do
    @old_enabled = ENV["ENDEAVOR_HISTORY_ENABLED"]
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @manager = user("manager", %w[manage_agendas approve_minutes manage_minutes record_minutes_approval])
    @adjutant = user("adjutant", %w[attest_minutes])
    @endeavor = @organization.endeavors.create!(title: "Car Show", summary: "Annual fundraiser", created_by: @manager)
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 2.days.ago, title: "September meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    section = @minutes.sections.first
    @item = section.items.create!(title: "Finance report", behavior_type: "report_slot", position: 1,
      body: "<p>The Car Show needs volunteers.</p><p>Electrical service is not confirmed.</p>")
    @item.outcomes.create!(kind: "motion", text: "Allocate half the Car Show profit to savings.", disposition: "adopted", position: 1)
    section.items.create!(title: "Unrelated report", behavior_type: "report_slot", position: 2, body: "UNRELATED_CANARY membership renewal.")
    @revision = attest(@minutes)
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "1"
    @provider = FakeProvider.new
  end

  teardown do
    ENV["ENDEAVOR_HISTORY_ENABLED"] = @old_enabled
  end

  test "full source discovery publishes automatically and preserves unlinked reports and decisions" do
    digest = @revision.sha256
    run = process
    assert_equal "succeeded", run.status
    assert_equal %w[discovery verify_discovery summary verify_summary], @provider.calls.map(&:first)
    assert_equal 2, @provider.calls.first.last["source"]["items"].size
    assert run.edition
    presenter = EndeavorHistory::Presenter.new(@endeavor.reload)
    text = presenter.overview.map { |claim| claim["text"] }.join(" ")
    assert_includes text, "not confirmed"
    assert_not_includes EndeavorHistory::Serialization.member(@endeavor).to_json, "UNRELATED_CANARY"
    assert_includes presenter.entries.to_json, "half the Car Show profit"
    assert_equal "adopted", presenter.entries.first[:items].first["units"].last["outcome"]["disposition"]
    assert_equal digest, @revision.reload.sha256
    assert_nil @item.reload.endeavor_id
    assert_equal 1, run.edition.source_links.count
  end

  test "member reading view keeps complete updates and decisions behind separate disclosures" do
    process
    history = EndeavorHistory::Presenter.new(@endeavor.reload)
    html = ApplicationController.render(partial: "endeavors/history", locals: { history: history })
    page = Nokogiri::HTML.fragment(html)
    meeting = page.at_css("details.history-meeting")
    assert meeting
    assert_nil meeting["open"]
    assert_equal 3, meeting.css(".history-update-list > li").size
    assert_equal [ "Decisions", "Discussion and updates" ], meeting.css(".history-claim-group h3").map(&:text)
    assert_includes meeting.at_css(".history-claim-group").text, "Allocate half"
    evidence = meeting.at_css("details.history-evidence")
    assert evidence
    assert_nil evidence["open"]
    assert_includes evidence.text, "Electrical service is not confirmed."
    assert_includes evidence.at_css(".history-decision").text, "Allocate half"
    assert page.css(".history-citations a").all? { |link| link["aria-label"].start_with?("Read supporting") }
  end

  test "uncited headline or missing decision title prevents automatic publication" do
    @provider.alter = ->(stage, _input, data) { data["meetings"].first["headline"]["fact_ids"] = [ "invented" ] if stage == "summary" }
    assert_equal "invalid_citation", process.error_category
    @provider.alter = ->(stage, _input, data) { data["meetings"].first["decision_titles"] = [] if stage == "summary" }
    assert_equal "coverage", process.error_category
    assert_empty @endeavor.history_editions
  end

  test "withdrawing generated history also withdraws its generated-only source reader links" do
    process
    history = EndeavorHistory::Presenter.new(@endeavor.reload)
    entry = history.entries.find { |row| row[:kind] == :meeting }
    item = entry[:items].first
    args = { revision_id: entry[:revision].id, record_key: item["key"], unit_ids: [ item["units"].first["id"] ] }
    assert_equal 1, history.source(**args)[:items].first["units"].size
    EndeavorHistory::Manage.change(@endeavor, user: @manager, action: "withdraw", lock_version: @endeavor.lock_version)
    assert_raises(ActiveRecord::RecordNotFound) { EndeavorHistory::Presenter.new(@endeavor.reload).source(**args) }
  end

  test "missing summary facts fail after one repair without replacing published evidence" do
    first = process
    @provider.alter = ->(stage, _input, data) { data["meetings"].first["claims"].pop if stage == "summary" }
    second = process
    assert_equal "failed", second.status
    assert_equal "coverage", second.error_category
    assert_nil second.edition
    assert_equal first.edition, EndeavorHistory::Presenter.new(@endeavor).edition
    assert_equal 2, @provider.calls.count { |stage, _| stage == "summary" } - 1
  end

  test "invalid or unsupported source citations never publish" do
    @provider.alter = ->(stage, _input, data) { data["items"].first["facts"].first["source_ids"] = [ "not-a-source" ] if stage == "discovery" }
    run = process
    assert_equal "invalid_citation", run.error_category
    assert_nil run.edition
    assert_equal 2, @provider.calls.size
  end

  test "verification findings fail even with valid citation ids" do
    @provider.alter = lambda do |stage, _input, data|
      if stage == "verify_summary"
        data["valid"] = false
        data["issues"] = [ { "message" => "A condition was omitted.", "source_ids" => [] } ]
      end
    end
    run = process
    assert_equal "verification_failed", run.error_category
    assert_nil run.edition
    assert_equal 6, @provider.calls.size
  end

  test "guidance is versioned data and changes invalidate an in-flight run" do
    run = new_run
    EndeavorHistory::Manage.change(@endeavor, user: @manager, action: "guidance", lock_version: @endeavor.lock_version, guidance: "Only this year's show.")
    EndeavorHistory::Processing.new(run, provider: @provider).call
    assert_equal "superseded", run.reload.status
    assert_empty @provider.calls
    assert_equal "Only this year's show.", @endeavor.history_guidances.last.body
  end

  test "withdrawal immediately suppresses generated history and resume needs a new edition" do
    process
    assert EndeavorHistory::Presenter.new(@endeavor).overview.any?
    EndeavorHistory::Manage.change(@endeavor, user: @manager, action: "withdraw", lock_version: @endeavor.lock_version)
    assert_empty EndeavorHistory::Presenter.new(@endeavor.reload).overview
    assert_raises(EndeavorHistory::Error) { EndeavorHistory::Processing.request(@endeavor) }
    EndeavorHistory::Manage.change(@endeavor, user: @manager, action: "resume", lock_version: @endeavor.lock_version)
    assert_empty EndeavorHistory::Presenter.new(@endeavor).overview
    assert_equal "succeeded", process.status
  end

  test "changed revision immediately hides stale summaries and sources during replacement" do
    process
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    @minutes.reopen_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes: @minutes, user: @manager,
      action: "reopen", evidence_note: "Synthetic correction.", action_payload: { "reason" => "Correct the allocation." }))
    assert EndeavorHistory::Presenter.new(@endeavor).overview.any?
    @item.update!(body: "Corrected wording about the show.")
    assert_includes EndeavorHistory::Presenter.new(@endeavor).entries.to_json, "not confirmed"
    attest(@minutes)
    assert_empty EndeavorHistory::Presenter.new(@endeavor).overview
    assert_not_includes EndeavorHistory::Presenter.new(@endeavor).entries.to_json, "not confirmed"
  end

  test "new approved payload freezes primary identity without rewriting older revisions" do
    assert_nil @revision.payload["sections"].first["items"].first["endeavor_id"]
    original = @revision.payload.deep_dup
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    @minutes.reopen_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes: @minutes, user: @manager,
      action: "reopen", evidence_note: "Synthetic identity correction.", action_payload: { "reason" => "Link the primary item." }))
    @item.update!(endeavor: @endeavor)
    replacement = attest(@minutes)
    assert_equal @endeavor.id, replacement.payload["sections"].first["items"].first["endeavor_id"]
    assert_equal original, @revision.reload.payload
  end

  test "request deduplicates active and successful automatic runs" do
    first = EndeavorHistory::Processing.request(@endeavor, requester: @manager)
    second = EndeavorHistory::Processing.request(@endeavor, requester: @manager)
    assert_equal first, second
    EndeavorHistory::Processing.new(first, provider: @provider).call
    assert_equal first, EndeavorHistory::Processing.request(@endeavor)
  end

  test "capability revocation prevents queued manual work" do
    run = new_run(requester: @manager)
    @manager.permission_grants.find_by!(capability: "manage_agendas").destroy!
    EndeavorHistory::Processing.new(run, provider: @provider).call
    assert_equal "forbidden", run.reload.error_category
    assert_empty @provider.calls
  end

  test "input limit stops without dropping text or calling a provider" do
    previous = ENV["ENDEAVOR_HISTORY_MAX_INPUT_BYTES"]
    ENV["ENDEAVOR_HISTORY_MAX_INPUT_BYTES"] = "100"
    run = process
    assert_equal "input_limit", run.error_category
    assert_empty @provider.calls
  ensure
    ENV["ENDEAVOR_HISTORY_MAX_INPUT_BYTES"] = previous
  end

  test "normalization preserves separate blocks and resolves original units" do
    source = EndeavorHistory::SourceDocument.new(@revision)
    assert_equal [ "The Car Show needs volunteers.", "Electrical service is not confirmed." ], source.items.first["units"].first(2).map { |unit| unit["text"] }
    assert source.units.all? { |unit| unit["id"].start_with?("r#{@revision.id}:") }
  end

  test "edition and evidence cannot be mutated" do
    run = process
    assert_not run.edition.update(payload: { "changed" => true })
    assert_not run.edition.source_links.first.destroy
  end

  test "daily budget refuses a request before provider access" do
    previous = ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"]
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = "1"
    run = process
    assert_equal "daily_budget", run.error_category
    assert_empty @provider.calls
  ensure
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = previous
  end

  test "a source change during final verification prevents publication" do
    @provider.alter = lambda do |stage, _input, _data|
      if stage == "verify_summary"
        EndeavorHistory::Manage.change(@endeavor, user: @manager, action: "guidance", lock_version: @endeavor.reload.lock_version, guidance: "This year's event only.")
      end
    end
    run = process
    assert_equal "superseded", run.status
    assert_nil run.edition
  end

  test "repeated source headings and multiple outcomes remain separate" do
    document = EndeavorHistory::SourceDocument.new(@revision).payload
    copied = document["items"].first.deep_dup
    copied["key"] = "other-key"
    copied["units"] = copied["units"].map { |unit| unit.merge("id" => "other-#{unit['id']}") }
    document["items"] << copied
    data = @provider.call(stage: "discovery", input: { "source" => document }, schema: EndeavorHistory::Schemas.discovery)["data"]
    assert_equal data, EndeavorHistory::Validate.discovery!(data, document)
    data["items"].pop
    assert_raises(EndeavorHistory::Error) { EndeavorHistory::Validate.discovery!(data, document) }
  end

  test "only new or corrected attestation queues AI reconciliation" do
    process
    clear_enqueued_jobs
    confirmation = OfficialActionConfirmation.record_external!(minutes: @minutes, user: @manager,
      action: "reopen", evidence_note: "Synthetic correction.", action_payload: { "reason" => "Correct wording." })
    assert_no_enqueued_jobs(only: EndeavorHistoryReconcileJob) do
      @minutes.reopen_with_confirmation!(confirmation: confirmation)
      @item.update!(body: "Corrected Car Show report.")
      approval = OfficialActionConfirmation.record_external!(minutes: @minutes, user: @manager,
        action: "approve", evidence_note: "Synthetic corrected approval.")
      @minutes.approve_with_confirmation!(confirmation: approval)
    end
    assert EndeavorHistory::Presenter.new(@endeavor).overview.any?
    confirmation = OfficialActionConfirmation.record_external!(minutes: @minutes, user: @adjutant,
      action: "attest", evidence_note: "Synthetic corrected attestation.")
    assert_enqueued_with(job: EndeavorHistoryReconcileJob, args: [ @organization.id ]) do
      @minutes.attest_with_confirmation!(confirmation: confirmation)
    end
    assert_empty EndeavorHistory::Presenter.new(@endeavor).overview
  end

  test "new attested meeting queues history and missed callbacks are recovered without duplicate runs" do
    process
    clear_enqueued_jobs
    meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago, title: "Later meeting")
    minutes = nil
    assert_no_enqueued_jobs(only: EndeavorHistoryReconcileJob) do
      minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)
      minutes.sections.first.items.create!(title: "Car Show", behavior_type: "report_slot", position: 1, body: "Volunteers confirmed.")
    end
    assert_enqueued_with(job: EndeavorHistoryReconcileJob, args: [ @organization.id ]) { attest(minutes) }
    clear_enqueued_jobs
    assert_enqueued_with(job: EndeavorHistoryRefreshJob, args: [ @endeavor.id ]) do
      EndeavorHistoryReconcileJob.perform_now(@organization.id)
    end
    assert_difference "EndeavorHistoryRun.count", 1 do
      EndeavorHistoryRefreshJob.perform_now(@endeavor.id)
    end
    run = @endeavor.history_runs.recent.first
    EndeavorHistory::Processing.new(run, provider: @provider).call
    assert_equal "succeeded", run.reload.status
    assert_no_difference "EndeavorHistoryRun.count" do
      assert_no_enqueued_jobs(only: EndeavorHistoryJob) { EndeavorHistoryRefreshJob.perform_now(@endeavor.id) }
    end
  end

  test "membership approval updates authority without regenerating unchanged minutes" do
    process
    clear_enqueued_jobs
    manifest = EndeavorHistory::Sources.new(@endeavor).manifest
    meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago, title: "Approval meeting")
    confirmation = OfficialActionConfirmation.record_external!(minutes: @minutes, user: @manager,
      action: "record_membership_approval", evidence_note: "Synthetic membership approval.",
      action_payload: { "approving_meeting_id" => meeting.id, "disposition" => "approved_as_presented" })
    assert_no_enqueued_jobs(only: EndeavorHistoryReconcileJob) do
      @minutes.record_membership_approval_with_confirmation!(confirmation: confirmation)
    end
    assert_equal manifest, EndeavorHistory::Sources.new(@endeavor).manifest
    assert_equal "Official minutes", EndeavorHistory::Presenter.new(@endeavor).entries.first[:authority]
  end

  test "new meeting reuses verified old evidence and preserves its account byte for byte" do
    first = process
    old_account = first.edition.payload["meetings"].first.to_json
    later_revision = add_meeting
    @provider.calls.clear
    run = automatic_process
    assert_equal "succeeded", run.status
    assert_equal %w[discovery verify_discovery summary verify_summary], @provider.calls.map(&:first)
    assert_equal [ later_revision.id ], @provider.calls.first.last["source"].slice("revision_id").values
    assert_equal [ later_revision.id ], @provider.calls.find { |stage, _| stage == "summary" }.last["account_revision_ids"]
    assert_equal old_account, run.edition.payload["meetings"].first.to_json
    assert_includes @provider.calls.find { |stage, _| stage == "summary" }.last.to_json, "not confirmed"
    assert @endeavor.history_events.where(endeavor_history_run: run, action: "reused").exists?
  end

  test "a new unmatched meeting retains prose without paid summary calls" do
    first = process
    add_meeting(title: "Unrelated report", body: "Membership renewals only.")
    @provider.calls.clear
    run = automatic_process
    assert_equal "succeeded", run.status
    assert_equal %w[discovery verify_discovery], @provider.calls.map(&:first)
    assert_equal first.edition.payload["overview"], run.edition.payload["overview"]
    assert_equal first.edition.payload["meetings"], run.edition.payload["meetings"]
    assert_equal 2, run.edition.payload["evidence"].size
    assert_empty run.edition.payload["evidence"].last["facts"]
  end

  test "a scoped manual refresh preserves other accounts and only rediscovers the selected revision" do
    process
    later = add_meeting
    previous = automatic_process.edition
    @provider.calls.clear
    run = EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true, meeting_id: @meeting.id)
    EndeavorHistory::Processing.new(run, provider: @provider).call
    assert_equal "succeeded", run.reload.status
    assert_equal [ @revision.id ], @provider.calls.select { |stage, _| stage == "discovery" }.map { |_, input| input["source"]["revision_id"] }
    assert_equal previous.payload["meetings"].find { |account| account["revision_id"] == later.id }, run.edition.payload["meetings"].find { |account| account["revision_id"] == later.id }
  end

  test "budget recovery resumes at verification after candidate generation completed" do
    previous = ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"]
    @provider.alter = ->(stage, _input, _data) { ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = "1" if stage == "discovery" }
    first = automatic_process
    assert_equal "daily_budget", first.error_category
    assert_equal [ "discovery" ], @provider.calls.map(&:first)
    assert_empty @endeavor.history_results
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = previous
    @provider.alter = nil
    @provider.calls.clear
    second = automatic_process
    assert_equal "succeeded", second.status
    assert_equal %w[verify_discovery summary verify_summary], @provider.calls.map(&:first)
    assert_equal 30, second.tokens
    assert_equal 10, first.tokens
  ensure
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = previous
  end

  test "a verified extraction survives interruption before composition" do
    previous = ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"]
    @provider.alter = ->(stage, _input, _data) { ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = "1" if stage == "verify_discovery" }
    first = automatic_process
    assert_equal "daily_budget", first.error_category
    assert_equal 1, @endeavor.history_results.count
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = previous
    @provider.alter = nil
    @provider.calls.clear
    assert_equal "succeeded", automatic_process.status
    assert_equal %w[summary verify_summary], @provider.calls.map(&:first)
  ensure
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = previous
  end

  test "raising verifier effort audits cached facts without repeating accepted extraction" do
    previous = ENV["OPENAI_ENDEAVOR_VERIFY_DISCOVERY_REASONING"]
    ENV["OPENAI_ENDEAVOR_VERIFY_DISCOVERY_REASONING"] = "low"
    automatic_process
    ENV["OPENAI_ENDEAVOR_VERIFY_DISCOVERY_REASONING"] = "high"
    add_meeting
    @provider.calls.clear
    run = automatic_process
    assert_equal "succeeded", run.status
    assert_equal %w[verify_discovery discovery verify_discovery summary verify_summary], @provider.calls.map(&:first)
    assert_equal @revision.id, @provider.calls.first.last["source"]["revision_id"]
    assert @endeavor.history_events.where(endeavor_history_run: run, action: "reused").any? { |event| event.metadata["comparison_rechecked"] }
  ensure
    ENV["OPENAI_ENDEAVOR_VERIFY_DISCOVERY_REASONING"] = previous
  end

  test "known Astra high verification remains reusable by the Sol high summary verifier" do
    run = new_run
    reuse = EndeavorHistory::Reuse.new(run)
    input = { "meetings" => [] }
    configuration = EndeavorHistory::Config.signature
    configuration["models"]["verify_summary"] = "gpt-6-astra"
    result = @endeavor.history_results.create!(endeavor_history_run: run, stage: "summary", fingerprint: reuse.fingerprint("summary", input),
      input: input, candidate: { "overview" => [], "meetings" => [] }, verification: { "valid" => true, "issues" => [] }, configuration: configuration)
    assert_equal result, reuse.verified("summary", input)
  end

  test "catalog additions audit prior matching without rewriting unchanged accounts" do
    first = process
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    @organization.endeavors.create!(title: "Building maintenance", created_by: @manager)
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "1"
    @provider.calls.clear
    second = automatic_process
    assert_equal "succeeded", second.status
    assert_equal [ "verify_discovery" ], @provider.calls.map(&:first)
    assert_equal first.edition.payload["meetings"], second.edition.payload["meetings"]
    assert_equal first.edition.payload["overview"], second.edition.payload["overview"]
  end

  test "a comparison conflict requires repaired extraction and cannot publish the old match" do
    process
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    @organization.endeavors.create!(title: "Car Show next year", created_by: @manager)
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "1"
    @provider.alter = lambda do |stage, _input, data|
      if stage == "verify_discovery"
        data["valid"] = false
        data["issues"] = [ { "message" => "Annual identity conflict.", "source_ids" => [] } ]
      end
    end
    @provider.calls.clear
    run = automatic_process
    assert_equal "verification_failed", run.error_category
    assert_nil run.edition
    assert_equal "verify_discovery", @provider.calls.first.first
    assert_equal 2, @provider.calls.count { |stage, _| stage == "discovery" }
  end

  test "changing model or prompt metadata does not automatically replay a successful archive" do
    first = automatic_process
    signature = EndeavorHistory::Config.signature.merge("model" => "gpt-6.1-sol", "prompt_version" => "future")
    original = EndeavorHistory::Config.method(:signature)
    EndeavorHistory::Config.define_singleton_method(:signature) { signature }
    begin
      assert_no_difference "EndeavorHistoryRun.count" do
        assert_equal first, EndeavorHistory::Processing.request(@endeavor)
      end
    ensure
      EndeavorHistory::Config.define_singleton_method(:signature, original)
    end
  end

  test "heading evidence has a stable citable id without changing old body or outcome ids" do
    current = EndeavorHistory::SourceDocument.new(@revision)
    legacy = EndeavorHistory::SourceDocument.new(@revision, version: "1")
    assert_equal legacy.units, current.units.reject { |unit| unit["kind"] == "title" }
    unit = current.units.find { |entry| entry["kind"] == "title" }
    assert_equal "r#{@revision.id}:#{current.items.first['key']}:title", unit["id"]
    assert_equal "Finance report", unit["text"]
  end

  test "verified results are immutable and scoped to their original Endeavor" do
    process
    result = @endeavor.history_results.first
    assert_not result.update(candidate: {})
    assert_not result.destroy
    other = @organization.endeavors.create!(title: "Other", created_by: @manager)
    foreign = EndeavorHistoryResult.new(result.attributes.except("id", "created_at", "updated_at").merge("endeavor_id" => other.id))
    assert_not foreign.valid?
  end

  test "a related date in a title cannot disappear behind valid body citations" do
    document = EndeavorHistory::SourceDocument.new(@revision).payload
    title = document["items"].first["units"].find { |unit| unit["kind"] == "title" }
    title["text"] = "Car Show - Sep 19"
    candidate = @provider.call(stage: "discovery", input: { "source" => document }, schema: EndeavorHistory::Schemas.discovery)["data"]
    error = assert_raises(EndeavorHistory::Error) { EndeavorHistory::Validate.discovery!(candidate, document) }
    assert_equal "coverage", error.category
    candidate["items"].first["facts"] << { "text" => "The event is scheduled for September 19.", "kind" => "report", "source_ids" => [ title["id"] ] }
    assert_equal candidate, EndeavorHistory::Validate.discovery!(candidate, document)
  end

  test "legacy adoption requires complete coverage and the exact accepting verification" do
    legacy_edition = legacy_edition_fixture
    add_meeting
    @provider.calls.clear
    run = automatic_process
    assert_equal "succeeded", run.status
    assert_equal %w[discovery verify_discovery summary verify_summary], @provider.calls.map(&:first)
    assert_equal legacy_edition.payload["meetings"].first, run.edition.payload["meetings"].first
    assert_equal "1", run.edition.payload["evidence"].first["normalization_version"]
  end

  test "a legacy edition without the accepting verifier is not reusable evidence" do
    legacy_edition_fixture(verified: false)
    @provider.calls.clear
    assert_equal "succeeded", automatic_process.status
    assert_equal %w[discovery verify_discovery summary verify_summary], @provider.calls.map(&:first)
    assert_equal "2", @endeavor.history_editions.last.payload["evidence"].first["normalization_version"]
  end

  test "automatic recovery preserves manual scope authority and completed refresh work" do
    automatic_process
    previous = ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"]
    @provider.alter = ->(stage, _input, _data) { ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = "1" if stage == "verify_discovery" }
    first = EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true, meeting_id: @meeting.id)
    EndeavorHistory::Processing.new(first, provider: @provider).call
    assert_equal "daily_budget", first.reload.error_category
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = previous
    @provider.alter = nil
    @provider.calls.clear
    second = EndeavorHistory::Processing.request(@endeavor, force: true)
    assert_equal @manager, second.requested_by
    metadata = @endeavor.history_events.find_by!(action: "requested", endeavor_history_run: second).metadata
    assert_equal first.id, metadata["refresh_id"]
    assert_equal @meeting.id, metadata["meeting_id"]
    EndeavorHistory::Processing.new(second, provider: @provider).call
    assert_equal "succeeded", second.reload.status
    assert_equal %w[summary verify_summary], @provider.calls.map(&:first)
  ensure
    ENV["ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET"] = previous
  end

  test "adopted legacy evidence remains reusable across later incremental editions" do
    legacy_edition_fixture
    add_meeting
    first = automatic_process
    add_meeting
    @provider.calls.clear
    second = automatic_process
    assert_equal "succeeded", second.status
    assert_equal first.edition.payload["evidence"].first, second.edition.payload["evidence"].first
    assert_equal %w[discovery verify_discovery summary verify_summary], @provider.calls.map(&:first)
  end

  test "a scoped legacy upgrade cannot fall back to the older policy on the next update" do
    legacy_edition_fixture
    run = EndeavorHistory::Processing.request(@endeavor, requester: @manager, force: true, meeting_id: @meeting.id)
    EndeavorHistory::Processing.new(run, provider: @provider).call
    assert_equal "succeeded", run.reload.status
    upgraded = run.edition.payload["evidence"].first
    assert_equal "2", upgraded["normalization_version"]
    add_meeting
    @provider.calls.clear
    next_run = automatic_process
    assert_equal "succeeded", next_run.status
    assert_equal upgraded, next_run.edition.payload["evidence"].first
    assert_equal %w[discovery verify_discovery summary verify_summary], @provider.calls.map(&:first)
  end

  test "known legacy financial-context gaps require a scoped source policy upgrade" do
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    @minutes.reopen_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes: @minutes, user: @manager,
      action: "reopen", evidence_note: "Synthetic financial context.", action_payload: { "reason" => "Add context." }))
    @item.update!(body: "The Car Show account has $500. The CD has $20,000 and matures September 20.")
    @revision = attest(@minutes)
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "1"
    legacy_edition_fixture
    @provider.calls.clear
    run = automatic_process
    assert_equal "succeeded", run.status
    assert_equal %w[discovery verify_discovery summary verify_summary], @provider.calls.map(&:first)
    assert_equal "2", run.edition.payload["evidence"].first["normalization_version"]
  end

  test "a late historical attestation follows meeting chronology and retains the later account" do
    previous = automatic_process.edition
    historical = add_meeting(starts_at: 3.days.ago)
    @provider.calls.clear
    run = automatic_process
    assert_equal "succeeded", run.status
    assert_equal [ historical.id, @revision.id ], run.edition.payload["evidence"].pluck("revision_id")
    assert_equal previous.payload["meetings"].first, run.edition.payload["meetings"].last
    input = @provider.calls.find { |stage, _| stage == "summary" }.last
    assert_equal [ historical.id ], input["account_revision_ids"]
    assert_equal @revision.id, input["meetings"].last["revision_id"]
  end

  private

  def legacy_edition_fixture(verified: true)
    source = EndeavorHistory::SourceDocument.new(@revision.reload, version: "1").payload.merge("target_endeavor_id" => @endeavor.id)
    manifest = EndeavorHistory::Sources.new(@endeavor).manifest.merge("configuration" => EndeavorHistory::Reuse::LEGACY_CONFIGURATION)
    input = { "endeavor" => manifest["endeavor"], "catalog" => manifest["catalog"], "guidance" => "", "source" => source }
    candidate = @provider.call(stage: "discovery", input: input, schema: EndeavorHistory::Schemas.discovery)["data"]
    facts = candidate["items"].flat_map do |entry|
      entry["facts"].each_with_index.map { |fact, index| fact.merge("id" => "r#{@revision.id}:#{entry['key']}:fact:#{index}") }
    end
    selected = source["items"].select { |item| item["units"].any? { |unit| facts.any? { |fact| fact["source_ids"].include?(unit["id"]) } } }
    evidence = source.except("target_endeavor_id").merge("items" => selected, "facts" => facts, "coverage" => candidate["items"])
    summary = @provider.call(stage: "summary", input: { "meetings" => [ evidence ] }, schema: EndeavorHistory::Schemas.summary)["data"]
    digest = ->(value) { Digest::SHA256.hexdigest(JSON.generate(value)) }
    steps = [ { "stage" => "discovery", "input_sha256" => digest.call(input), "data" => candidate } ]
    steps << { "stage" => "verify_discovery", "input_sha256" => digest.call(input.merge("candidate" => candidate)), "data" => { "valid" => true, "issues" => [] } } if verified
    run = @endeavor.history_runs.create!(manifest: manifest, fingerprint: digest.call(manifest), steps: steps, status: "succeeded")
    payload = summary.merge("evidence" => [ evidence ])
    @endeavor.history_editions.create!(endeavor_history_run: run, manifest: manifest, payload: payload, sha256: digest.call(payload))
  end

  def automatic_process
    manifest = EndeavorHistory::Sources.new(@endeavor.reload).manifest
    run = @endeavor.history_runs.create!(manifest: manifest, fingerprint: EndeavorHistory::Sources.digest(manifest))
    EndeavorHistory::Processing.new(run, provider: @provider).call
    run.reload
  end

  def add_meeting(title: "Car Show", body: "Volunteers confirmed.", starts_at: 1.day.ago)
    previous = ENV["ENDEAVOR_HISTORY_ENABLED"]
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: starts_at, title: "Later meeting")
    minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)
    minutes.sections.first.items.create!(title: title, behavior_type: "report_slot", position: 1, body: body)
    attest(minutes)
  ensure
    ENV["ENDEAVOR_HISTORY_ENABLED"] = previous
  end

  def new_run(requester: nil)
    manifest = EndeavorHistory::Sources.new(@endeavor.reload).manifest
    run = @endeavor.history_runs.create!(manifest: manifest, fingerprint: EndeavorHistory::Sources.digest(manifest), requested_by: requester)
    @endeavor.history_events.create!(action: "requested", endeavor_history_run: run, metadata: { "refresh" => true })
    run
  end

  def process
    run = new_run
    EndeavorHistory::Processing.new(run, provider: @provider).call
    run.reload
  end

  def attest(minutes)
    approval = OfficialActionConfirmation.record_external!(minutes: minutes, user: @manager, action: "approve", evidence_note: "Synthetic test approval.")
    revision = minutes.approve_with_confirmation!(confirmation: approval)
    attestation = OfficialActionConfirmation.record_external!(minutes: minutes, user: @adjutant, action: "attest", evidence_note: "Synthetic test attestation.")
    minutes.attest_with_confirmation!(confirmation: attestation)
    revision
  end

  def user(name, capabilities)
    person = Person.create!(first_name: name, last_name: "Example")
    user = User.create!(person: person, email_address: "#{name}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| user.permission_grants.create!(capability: capability) }
    user
  end
end
