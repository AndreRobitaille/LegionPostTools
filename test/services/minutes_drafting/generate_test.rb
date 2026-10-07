require "test_helper"

class MinutesDrafting::GenerateTest < ActiveSupport::TestCase
  FakeProvider = Data.define(:result) do
    def draft(**) = result
  end

  class BackgroundProvider
    attr_reader :submissions, :retrieved_ids, :cancelled_ids
    attr_accessor :before_retrieve, :cancel_error

    def initialize(*results)
      @results = results
      @submissions = 0
      @retrieved_ids = []
      @cancelled_ids = []
    end

    def draft(**)
      @submissions += 1
      next_result
    end

    def retrieve(response_id:)
      @retrieved_ids << response_id
      before_retrieve&.call
      next_result
    end

    def cancel(response_id:)
      @cancelled_ids << response_id
      raise cancel_error if cancel_error
    end

    private

    def next_result
      result = @results.shift
      raise result if result.is_a?(Exception)
      raise "No synthetic response remains" unless result

      result
    end
  end

  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Post Hall",
      timezone: "America/Chicago"
    )
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago)
    @requester = create_user!("Adjutant")
    @endeavor = @organization.endeavors.create!(
      title: "Veteran flag outreach",
      summary: "Provide flags to local veterans and families.",
      importance: "standard",
      status: "active",
      created_by: @requester
    )
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @section = @minutes.sections.first
    @item = @section.items.create!(title: "New business", behavior_type: "business_item", position: 1)
    @attendance = @minutes.attendance_entries.create!(office_name: "Commander", status: "not_recorded", position: 1)
    @transcript = MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @requester,
      retention_policy: "delete_after_acceptance",
      pasted_text: "The service project was discussed. A motion was made to buy flags. The motion carried. Commander answered here."
    ).call
  end

  test "records provenance and stages source-bound suggestions without changing minutes" do
    result = provider_result([
      suggestion("item_summary", @item.id, body: "Members discussed the service project."),
      suggestion("outcome", @item.id, body: "Purchase flags.", outcome_kind: "motion", disposition: "adopted"),
      suggestion("attendance", @attendance.id, attendance_status: "present")
    ])
    @run = MinutesDrafting::Generate.prepare(minutes: @minutes, requester: @requester)

    assert_predicate @run, :pending?
    assert_nil @run.started_at

    assert_no_changes -> { @item.reload.body.to_plain_text } do
      @run = MinutesDrafting::Generate.call(run: @run, provider: FakeProvider.new(result))
    end

    assert_predicate @run, :succeeded?
    assert_equal "gpt-6-astra", @run.model
    assert_equal "high", @run.reasoning_effort
    assert_equal "medium", @run.text_verbosity
    assert_equal MinutesDrafting::Prompt.sha256, @run.prompt_sha256
    assert_equal @transcript.sha256_digest, @run.source_sha256
    assert_equal 3, @run.suggestions.count
    assert_equal %w[item_summary outcome attendance], @run.suggestions.pluck(:kind)
    assert_equal "not_recorded", @attendance.reload.status
    assert_empty @item.outcomes
  end

  test "new Endeavor proposals are staged without creating or linking until explicit human confirmation" do
    PermissionGrant.create!(user: @requester, capability: "manage_minutes")
    PermissionGrant.create!(user: @requester, capability: "manage_agendas")
    result = provider_result([ suggestion("endeavor_proposal", @item.id,
      title: "Community breakfast", body: "Plan a breakfast and recruit volunteers.",
      endeavor_reason: "The Post agreed to continuing planning and volunteer recruitment.") ])

    assert_no_difference "Endeavor.count" do
      @run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: FakeProvider.new(result))
    end
    proposal = @run.suggestions.sole
    assert_nil @item.reload.endeavor_id
    assert_equal "minutes-suggestions-v3", @run.schema_version

    assert_no_difference "Endeavor.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        MinutesDrafting::ReviewSuggestion.call(suggestion: proposal, reviewer: @requester, action: "use")
      end
    end
    assert proposal.reload.unreviewed?
    assert_difference "Endeavor.count", 1 do
      MinutesDrafting::ReviewSuggestion.call(suggestion: proposal, reviewer: @requester, action: "use",
        edits: { endeavor_action: "create", title: proposal.payload["title"], body: proposal.payload["body"], lock_version: @item.lock_version })
    end
    assert_equal "used", proposal.reload.review_state
    assert_equal "Community breakfast", @item.reload.endeavor.title
    assert_equal @requester, proposal.reviewed_by
  end

  test "proposal for existing work reuses its exact id and human confirmation creates no Endeavor" do
    PermissionGrant.create!(user: @requester, capability: "manage_minutes")
    result = provider_result([ suggestion("endeavor_proposal", @item.id, endeavor_id: @endeavor.id,
      endeavor_reason: "The continuing flag outreach needs the same volunteer coordination.") ])
    run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: FakeProvider.new(result))
    proposal = run.suggestions.sole
    assert_equal @endeavor.title, proposal.payload["title"]
    assert_equal @endeavor.summary, proposal.payload["body"]
    assert_no_difference "Endeavor.count" do
      MinutesDrafting::ReviewSuggestion.call(suggestion: proposal, reviewer: @requester, action: "use",
        edits: { endeavor_action: "link", endeavor_id: @endeavor.id, lock_version: @item.lock_version })
    end
    assert_equal @endeavor, @item.reload.endeavor
    assert_equal "used", proposal.reload.review_state
  end

  test "proposal cannot change a confirmed Endeavor link or invent an existing identity" do
    @item.update!(endeavor: @endeavor)
    result = provider_result([ suggestion("endeavor_proposal", @item.id, endeavor_id: @endeavor.id,
      endeavor_reason: "Continuing work.") ])
    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: FakeProvider.new(result))
    end
    assert_equal @endeavor, @item.reload.endeavor
    @item.update!(endeavor: nil)
    result = provider_result([ suggestion("endeavor_proposal", @item.id, endeavor_id: @endeavor.id + 100_000,
      endeavor_reason: "Continuing work.") ])
    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: FakeProvider.new(result))
    end
  end

  test "duplicate proposals for one item roll back the entire generated result" do
    attributes = suggestion("endeavor_proposal", @item.id, title: "Breakfast", body: "Plan the breakfast.", endeavor_reason: "Continuing planning.")
    assert_no_difference "MinutesDraftSuggestion.count" do
      assert_raises(MinutesDrafting::Generate::DraftFailed) do
        MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: FakeProvider.new(provider_result([ attributes, attributes ])))
      end
    end
  end

  test "missing rationale and cross-meeting targets reject new Endeavor proposals" do
    result = provider_result([ suggestion("endeavor_proposal", @item.id, title: "Breakfast", body: "Plan a breakfast.") ])
    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: FakeProvider.new(result))
    end
    other_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 2.days.ago)
    other = MeetingMinutes.create_from_meeting!(meeting: other_meeting).sections.first.items.create!(title: "Other", behavior_type: "business_item", position: 1)
    result = provider_result([ suggestion("endeavor_proposal", other.id, title: "Breakfast", body: "Plan a breakfast.", endeavor_reason: "Continuing work.") ])
    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: FakeProvider.new(result))
    end
  end

  test "a queued older prompt fails before a provider call and asks for a current retry" do
    run = MinutesDrafting::Generate.prepare(minutes: @minutes, requester: @requester)
    run.update!(prompt_sha256: "old-prompt", schema_version: "minutes-suggestions-v2")
    provider = Object.new
    def provider.draft(**) = raise("An outdated run must not call the provider")
    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(run: run, provider: provider)
    end
    assert_equal "draft_version_changed", run.reload.error_category
  end

  test "redelivering an older completed run retains its successful historical record" do
    run = MinutesDrafting::Generate.prepare(minutes: @minutes, requester: @requester)
    run.update!(prompt_sha256: "old-prompt", schema_version: "minutes-suggestions-v2", status: "succeeded", completed_at: Time.current)
    provider = Object.new
    def provider.draft(**) = raise("A completed run must not call the provider")
    assert_no_changes -> { [ run.reload.status, run.completed_at, run.error_category ] } do
      MinutesDrafting::Generate.call(run: run, provider: provider)
    end
  end

  test "rejects output that targets a record outside these minutes" do
    other_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 2.days.ago)
    other_minutes = MeetingMinutes.create_from_meeting!(meeting: other_meeting)
    other_item = other_minutes.sections.first.items.create!(title: "Other", behavior_type: "business_item", position: 1)
    result = provider_result([ suggestion("item_summary", other_item.id, body: "Crossed boundary.") ])

    error = assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: FakeProvider.new(result))
    end

    assert_predicate error.run, :failed?
    assert_equal "invalid_output", error.run.error_category
    assert_empty error.run.suggestions
    assert_predicate @item.reload.body.to_plain_text, :blank?
  end

  test "using editing and discarding are independent human review actions" do
    @item.update!(body: "Human wording retained.")
    run = MinutesDrafting::Generate.call(
      minutes: @minutes,
      requester: @requester,
      provider: FakeProvider.new(provider_result([
        suggestion("item_summary", @item.id, body: "AI wording."),
        suggestion("outcome", @item.id, body: "Buy flags.", outcome_kind: "motion", disposition: "not_recorded"),
        suggestion("attendance", @attendance.id, attendance_status: "present")
      ]))
    )
    summary, outcome, attendance = run.suggestions.to_a

    MinutesDrafting::ReviewSuggestion.call(suggestion: summary, reviewer: @requester, action: "edit", edits: { body: "Adjutant-corrected wording." })
    MinutesDrafting::ReviewSuggestion.call(suggestion: outcome, reviewer: @requester, action: "discard")
    MinutesDrafting::ReviewSuggestion.call(suggestion: attendance, reviewer: @requester, action: "use")

    assert_equal "Human wording retained. Adjutant-corrected wording.", @item.reload.body.to_plain_text.squish
    assert_empty @item.outcomes
    assert_equal "present", @attendance.reload.status
    assert_equal %w[edited discarded used], run.suggestions.pluck(:review_state)
    assert run.suggestions.all? { |suggestion| suggestion.reviewed_by == @requester && suggestion.reviewed_at.present? }
  end

  test "separately supported paragraphs append without overwriting prior minutes wording" do
    @item.update!(body: "Human wording retained.")
    run = MinutesDrafting::Generate.call(
      minutes: @minutes,
      requester: @requester,
      provider: FakeProvider.new(provider_result([
        suggestion("item_summary", @item.id, body: "First supported paragraph."),
        suggestion("item_summary", @item.id, body: "Second supported paragraph.")
      ]))
    )

    run.suggestions.each do |suggestion|
      MinutesDrafting::ReviewSuggestion.call(suggestion: suggestion, reviewer: @requester, action: "use")
    end

    assert_equal(
      "Human wording retained. First supported paragraph. Second supported paragraph.",
      @item.reload.body.to_plain_text.squish
    )
  end

  test "prompt distinguishes agenda wording from existing minutes" do
    @item.update!(agenda_body: "Bring committee dates.", body: "The committee reported progress.")

    input = JSON.parse(MinutesDrafting::Prompt.input(
      minutes: @minutes,
      source_document: MinutesDrafting::SourceDocument.new(@transcript.source_text)
    ))
    item_input = input.fetch("outline").flat_map { |section| section.fetch("items") }
      .find { |item| item.fetch("minutes_item_id") == @item.id }

    assert_equal "Bring committee dates.", item_input.fetch("agenda_wording")
    assert_equal "The committee reported progress.", item_input.fetch("existing_minutes")
    assert_not item_input.key?("existing_wording")
  end

  test "stages and applies an added item linked to an exact supplied Endeavor" do
    input = JSON.parse(MinutesDrafting::Prompt.input(
      minutes: @minutes,
      source_document: MinutesDrafting::SourceDocument.new(@transcript.source_text)
    ))

    assert_equal(
      {
        "endeavor_id" => @endeavor.id,
        "title" => "Veteran flag outreach",
        "summary" => "Provide flags to local veterans and families.",
        "status" => "active"
      },
      input.fetch("available_endeavors").sole
    )

    run = MinutesDrafting::Generate.call(
      minutes: @minutes,
      requester: @requester,
      provider: FakeProvider.new(provider_result([
        suggestion(
          "additional_item",
          @section.id,
          title: "Flag outreach",
          body: "Members discussed providing flags to veterans.",
          endeavor_id: @endeavor.id
        )
      ]))
    )
    suggestion = run.suggestions.sole

    assert_equal @endeavor.id, suggestion.payload.fetch("endeavor_id")
    assert_equal @endeavor.title, suggestion.payload.fetch("endeavor_title")

    MinutesDrafting::ReviewSuggestion.call(suggestion: suggestion, reviewer: @requester, action: "use")

    added_item = @section.items.reload.last
    assert_equal @endeavor, added_item.endeavor
    assert_equal "Flag outreach", added_item.title
  end

  test "rejects an Endeavor id that was not supplied to the model" do
    unavailable = @organization.endeavors.create!(
      title: "Already completed",
      importance: "standard",
      status: "completed",
      created_by: @requester,
      completed_by: @requester,
      completed_at: @minutes.starts_at - 1.day
    )

    error = assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(
        minutes: @minutes,
        requester: @requester,
        provider: FakeProvider.new(provider_result([
          suggestion(
            "additional_item",
            @section.id,
            title: "Old work",
            body: "Members mentioned old work.",
            endeavor_id: unavailable.id
          )
        ]))
      )
    end

    assert_equal "invalid_output", error.run.error_category
    assert_empty error.run.suggestions
  end

  test "rejects an Endeavor link on a suggestion for an existing agenda item" do
    error = assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(
        minutes: @minutes,
        requester: @requester,
        provider: FakeProvider.new(provider_result([
          suggestion(
            "item_summary",
            @item.id,
            body: "Members discussed flag outreach.",
            endeavor_id: @endeavor.id
          )
        ]))
      )
    end

    assert_equal "invalid_output", error.run.error_category
    assert_empty error.run.suggestions
  end

  test "human correction can remove a proposed Endeavor link" do
    run = MinutesDrafting::Generate.call(
      minutes: @minutes,
      requester: @requester,
      provider: FakeProvider.new(provider_result([
        suggestion(
          "additional_item",
          @section.id,
          title: "Flag outreach",
          body: "Members discussed providing flags to veterans.",
          endeavor_id: @endeavor.id
        )
      ]))
    )

    MinutesDrafting::ReviewSuggestion.call(
      suggestion: run.suggestions.sole,
      reviewer: @requester,
      action: "edit",
      edits: { endeavor_id: "" }
    )

    assert_nil @section.items.reload.last.endeavor
  end

  test "persists the background identifier and polls one generation until suggestions are ready" do
    provider = BackgroundProvider.new(pending_result, pending_result, provider_result([ suggestion("item_summary", @item.id, body: "Members discussed the project.") ]))
    run = MinutesDrafting::Generate.prepare(minutes: @minutes, requester: @requester)

    assert_no_changes -> { @item.reload.body.to_plain_text } do
      MinutesDrafting::Generate.call(run: run, provider: provider)
      assert_predicate run.reload, :running?
      assert_equal "resp_test", run.provider_response_id
      assert_equal "req_submitted", run.provider_request_id
      assert_empty run.suggestions
      started_at = run.started_at

      travel 7.minutes do
        MinutesDrafting::Generate.call(run: run, provider: provider)
        assert_predicate run.reload, :running?
        assert_equal started_at, run.started_at
        MinutesDrafting::Generate.call(run: run, provider: provider)
      end
    end

    assert_predicate run.reload, :succeeded?
    assert_equal 1, provider.submissions
    assert_equal [ "resp_test", "resp_test" ], provider.retrieved_ids
    assert_equal 1, run.suggestions.count
    assert_equal "not_recorded", @attendance.reload.status
    assert_empty @item.outcomes
  end

  test "a retrieval timeout leaves the known generation running and the next poll can finish it" do
    timeout = MinutesDraftProviders::Error.new(category: "timeout", retryable: true)
    provider = BackgroundProvider.new(pending_result, timeout, provider_result([]))
    run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)

    MinutesDrafting::Generate.call(run: run, provider: provider)
    assert_predicate run.reload, :running?
    assert_equal "resp_test", run.provider_response_id
    assert_equal "req_submitted", run.provider_request_id
    assert_nil run.error_category

    MinutesDrafting::Generate.call(run: run, provider: provider)
    assert_predicate run.reload, :succeeded?
    assert_equal 1, provider.submissions
    assert_empty provider.cancelled_ids
  end

  test "an initial timeout fails once without submitting a replacement generation" do
    provider = BackgroundProvider.new(MinutesDraftProviders::Error.new(category: "timeout", retryable: true))
    error = assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)
    end

    assert_predicate error.run.reload, :failed?
    assert_equal "timeout", error.run.error_category
    assert_equal 1, provider.submissions
    assert_nil error.run.provider_response_id
  end

  test "the overall deadline cancels the existing response and retains its provenance" do
    provider = BackgroundProvider.new(pending_result)
    run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)
    provider.cancel_error = MinutesDraftProviders::Error.new(category: "provider_error")

    travel (MinutesDrafting::Generate::GENERATION_TIMEOUT_SECONDS + 1).seconds do
      assert_raises(MinutesDrafting::Generate::DraftFailed) do
        MinutesDrafting::Generate.call(run: run, provider: provider)
      end
    end

    assert_predicate run.reload, :failed?
    assert_equal "timeout", run.error_category
    assert_equal "resp_test", run.provider_response_id
    assert_equal "req_submitted", run.provider_request_id
    assert_equal [ "resp_test" ], provider.cancelled_ids
    assert_empty provider.retrieved_ids
    assert_equal 1, provider.submissions
    assert_empty run.suggestions
  end

  test "terminal retrieval errors keep the original identifiers without resubmitting" do
    provider = BackgroundProvider.new(pending_result, MinutesDraftProviders::Error.new(category: "configuration"))
    run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)

    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(run: run, provider: provider)
    end

    assert_predicate run.reload, :failed?
    assert_equal "configuration", run.error_category
    assert_equal "resp_test", run.provider_response_id
    assert_equal "req_submitted", run.provider_request_id
    assert_equal 1, provider.submissions
  end

  test "a poll finishing after the overall deadline fails without staging its result" do
    provider = BackgroundProvider.new(pending_result, provider_result([ suggestion("item_summary", @item.id, body: "Late result.") ]))
    run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)
    provider.before_retrieve = -> { travel (MinutesDrafting::Generate::GENERATION_TIMEOUT_SECONDS + 1).seconds }

    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(run: run, provider: provider)
    end

    assert_equal "timeout", run.reload.error_category
    assert_equal "resp_test", run.provider_response_id
    assert_equal "req_test", run.provider_request_id
    assert_empty run.suggestions
    assert_equal 1, provider.submissions
  end

  test "a completed response rejected by local validation still records its provider identifiers" do
    result = provider_result([ suggestion("item_summary", -1, body: "Unknown target.") ])
    error = assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: FakeProvider.new(result))
    end

    assert_equal "invalid_output", error.run.reload.error_category
    assert_equal "resp_test", error.run.provider_response_id
    assert_equal "req_test", error.run.provider_request_id
    assert_empty error.run.suggestions
  end

  test "a delayed submission reply retains and cancels its known response when the deadline has elapsed" do
    reply = pending_result
    provider = Object.new
    cancellations = []
    delay = -> { travel (MinutesDrafting::Generate::GENERATION_TIMEOUT_SECONDS + 1).seconds }
    provider.define_singleton_method(:draft) do |**|
      delay.call
      reply
    end
    provider.define_singleton_method(:cancel) { |response_id:| cancellations << response_id }

    error = assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)
    end

    assert_equal "timeout", error.run.reload.error_category
    assert_equal "resp_test", error.run.provider_response_id
    assert_equal "req_submitted", error.run.provider_request_id
    assert_equal [ "resp_test" ], cancellations
  end

  test "a running attempt with an unknown response ID never resubmits" do
    run = MinutesDrafting::Generate.prepare(minutes: @minutes, requester: @requester)
    run.update!(status: "running", started_at: Time.current)
    provider = BackgroundProvider.new

    MinutesDrafting::Generate.call(run: run, provider: provider)

    assert_predicate run.reload, :running?
    assert_equal 0, provider.submissions
    assert_empty provider.retrieved_ids
  end

  test "source changes while awaiting OpenAI cancel the known response before retrieval" do
    provider = BackgroundProvider.new(pending_result)
    run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)
    @transcript.update!(sha256_digest: "a" * 64)

    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(run: run, provider: provider)
    end

    assert_equal "source_unavailable", run.reload.error_category
    assert_equal [ "resp_test" ], provider.cancelled_ids
    assert_empty provider.retrieved_ids
    assert_empty run.suggestions
  end

  test "source changes during retrieval prevent completed output from being staged" do
    provider = BackgroundProvider.new(pending_result, provider_result([ suggestion("item_summary", @item.id, body: "Changed source.") ]))
    run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)
    provider.before_retrieve = -> { @transcript.update!(sha256_digest: "a" * 64) }

    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(run: run, provider: provider)
    end

    assert_equal "source_unavailable", run.reload.error_category
    assert_empty run.suggestions
    assert_empty @item.reload.body.to_plain_text
  end

  test "released minutes prevent a completed background result from being staged" do
    provider = BackgroundProvider.new(pending_result, provider_result([]))
    run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)
    provider.before_retrieve = -> { @minutes.update_columns(status: "attested") }

    assert_raises(MinutesDrafting::Generate::DraftFailed) do
      MinutesDrafting::Generate.call(run: run, provider: provider)
    end

    assert_equal "source_unavailable", run.reload.error_category
    assert_empty run.suggestions
  end

  test "duplicate completion cannot stage suggestions for a terminal run" do
    provider = BackgroundProvider.new(pending_result, provider_result([ suggestion("item_summary", @item.id, body: "Duplicate.") ]))
    run = MinutesDrafting::Generate.call(minutes: @minutes, requester: @requester, provider: provider)
    provider.before_retrieve = -> { run.update!(status: "succeeded", completed_at: Time.current) }

    assert_no_difference "MinutesDraftSuggestion.count" do
      MinutesDrafting::Generate.call(run: run, provider: provider)
    end
    assert_predicate run.reload, :succeeded?

    MinutesDrafting::Generate.call(run: run, provider: provider)
    assert_equal [ "resp_test" ], provider.retrieved_ids
    assert_equal 1, provider.submissions
  end

  private

  def pending_result
    MinutesDraftProviders::Pending.new(provider_response_id: "resp_test", provider_request_id: "req_submitted")
  end

  def provider_result(suggestions)
    MinutesDraftProviders::Result.new(
      data: { "suggestions" => suggestions },
      provider_response_id: "resp_test",
      provider_request_id: "req_test",
      model: "gpt-6-astra",
      input_tokens: 1_000,
      output_tokens: 200,
      reasoning_tokens: 80,
      total_tokens: 1_200
    )
  end

  def suggestion(kind, target_id, **overrides)
    {
      "kind" => kind,
      "target_id" => target_id,
      "source_agenda_item_id" => nil,
      "endeavor_id" => nil,
      "endeavor_reason" => nil,
      "title" => nil,
      "body" => nil,
      "outcome_kind" => nil,
      "disposition" => nil,
      "mover_name" => nil,
      "seconder_name" => nil,
      "vote_summary" => nil,
      "attendance_status" => nil,
      "source_start_line" => 1,
      "source_end_line" => 1,
      "confidence" => "medium",
      "missing_facts" => []
    }.merge(overrides.stringify_keys)
  end

  def create_user!(name)
    person = Person.create!(first_name: name, last_name: "Officer")
    User.create!(person: person, email_address: "#{name.parameterize}-#{SecureRandom.hex(3)}@example.com", email_verified_at: Time.current)
  end
end
