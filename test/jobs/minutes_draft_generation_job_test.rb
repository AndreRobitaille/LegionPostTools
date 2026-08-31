require "test_helper"

class MinutesDraftGenerationJobTest < ActiveJob::TestCase
  setup do
    organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Post Hall",
      timezone: "America/Chicago"
    )
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: organization, meeting_body: body, starts_at: 1.day.ago)
    requester = User.create!(
      person: Person.create!(first_name: "Test", last_name: "Adjutant"),
      email_address: "draft-job@example.com"
    )
    minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)
    MeetingTranscripts::Create.new(
      meeting: meeting,
      created_by: requester,
      retention_policy: "delete_after_acceptance",
      pasted_text: "The Commander called the meeting to order."
    ).call
    @run = MinutesDrafting::Generate.prepare(minutes: minutes, requester: requester)
  end

  test "delegates the prepared run to the drafting service" do
    received = []
    replacement = ->(run:) { received << run }

    with_stubbed_generate(replacement) do
      MinutesDraftGenerationJob.perform_now(@run)
    end

    assert_equal [ @run ], received
    assert_predicate @run.reload, :pending?
  end

  test "records a safe failure state when the worker stops unexpectedly" do
    replacement = ->(run:) { raise "unexpected test failure" }

    with_stubbed_generate(replacement) do
      assert_raises(RuntimeError) { MinutesDraftGenerationJob.perform_now(@run) }
    end

    assert_predicate @run.reload, :failed?
    assert_equal "worker_error", @run.error_category
    assert_not_nil @run.completed_at
  end

  private

  def with_stubbed_generate(replacement)
    original = MinutesDrafting::Generate.method(:call)
    MinutesDrafting::Generate.define_singleton_method(:call, replacement)
    yield
  ensure
    MinutesDrafting::Generate.define_singleton_method(:call, original)
  end
end
