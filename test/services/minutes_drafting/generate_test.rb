require "test_helper"

class MinutesDrafting::GenerateTest < ActiveSupport::TestCase
  FakeProvider = Data.define(:result) do
    def draft(**) = result
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
    assert_equal "gpt-5.6-sol", @run.model
    assert_equal "high", @run.reasoning_effort
    assert_equal "medium", @run.text_verbosity
    assert_equal MinutesDrafting::Prompt.sha256, @run.prompt_sha256
    assert_equal @transcript.sha256_digest, @run.source_sha256
    assert_equal 3, @run.suggestions.count
    assert_equal %w[item_summary outcome attendance], @run.suggestions.pluck(:kind)
    assert_equal "not_recorded", @attendance.reload.status
    assert_empty @item.outcomes
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

  private

  def provider_result(suggestions)
    MinutesDraftProviders::Result.new(
      data: { "suggestions" => suggestions },
      provider_response_id: "resp_test",
      provider_request_id: "req_test",
      model: "gpt-5.6-sol",
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
