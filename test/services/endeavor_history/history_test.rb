require "test_helper"

class EndeavorHistoryTest < ActiveSupport::TestCase
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
          units = item.fetch("units")
          relevant = item["title"] != "Unrelated report"
          { "key" => item["key"], "relevance" => relevant ? "related" : "no_match", "reason" => "Source matches the named event.",
            "facts" => relevant ? units.map { |unit| { "text" => unit["text"], "kind" => "report", "source_ids" => [ unit["id"] ] } } : [],
            "outcomes" => units.select { |unit| unit["kind"] == "outcome" }.map { |unit| { "source_id" => unit["id"], "relevant" => relevant, "reason" => "Recorded event decision." } } }
        end }
      when "summary"
        meetings = input.fetch("meetings").select { |meeting| meeting["facts"].any? }.map do |meeting|
          { "revision_id" => meeting["revision_id"], "headline" => { "text" => "Volunteer needs and recorded decisions", "fact_ids" => [ meeting["facts"].first["id"] ] },
            "decision_titles" => meeting["items"].flat_map { |item| item["units"].select { |unit| unit["kind"] == "outcome" }.map { |unit| { "source_id" => unit["id"], "text" => "Fund allocation" } } },
            "claims" => meeting["facts"].map { |fact| { "text" => fact["text"], "fact_ids" => [ fact["id"] ] } } }
        end
        { "overview" => meetings.flat_map { |meeting| meeting["claims"] }.first(2), "meetings" => meetings }
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

  private

  def new_run(requester: nil)
    manifest = EndeavorHistory::Sources.new(@endeavor.reload).manifest
    @endeavor.history_runs.create!(manifest: manifest, fingerprint: EndeavorHistory::Sources.digest(manifest), requested_by: requester)
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
