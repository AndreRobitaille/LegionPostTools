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

  test "schedules another short job while the same background response is running" do
    replacement = ->(run:) { run.update!(status: "running", started_at: Time.current, provider_response_id: "resp_pending") }

    freeze_time do
      with_stubbed_generate(replacement) do
        assert_enqueued_with(job: MinutesDraftGenerationJob, args: [ @run ], at: 10.seconds.from_now) do
          MinutesDraftGenerationJob.perform_now(@run)
        end
      end
    end

    assert_equal "resp_pending", @run.reload.provider_response_id
  end

  test "a completed generation does not schedule another poll" do
    replacement = ->(run:) { run.update!(status: "succeeded", completed_at: Time.current) }

    with_stubbed_generate(replacement) do
      assert_no_enqueued_jobs { MinutesDraftGenerationJob.perform_now(@run) }
    end
  end

  test "queued jobs submit once and retrieve the same response until completion" do
    pending = MinutesDraftProviders::Pending.new(provider_response_id: "resp_pending", provider_request_id: "req_submitted")
    completed = MinutesDraftProviders::Result.new(data: { "suggestions" => [] }, provider_response_id: "resp_pending",
      provider_request_id: "req_completed", model: "synthetic-offline", input_tokens: 0,
      output_tokens: 0, reasoning_tokens: 0, total_tokens: 0)
    results = [ pending, pending, completed ]
    submissions = []
    retrievals = []
    provider = Object.new
    provider.define_singleton_method(:draft) do |**|
      submissions << true
      results.shift
    end
    provider.define_singleton_method(:retrieve) do |response_id:|
      retrievals << response_id
      results.shift
    end
    generate = MinutesDrafting::Generate.method(:call)
    replacement = ->(run:) { generate.call(run: run, provider: provider) }

    with_stubbed_generate(replacement) do
      assert_performed_jobs 3 do
        perform_enqueued_jobs { MinutesDraftGenerationJob.perform_later(@run) }
      end
    end

    assert_predicate @run.reload, :succeeded?
    assert_equal 1, submissions.length
    assert_equal [ "resp_pending", "resp_pending" ], retrievals
    assert_equal "resp_pending", @run.provider_response_id
    assert_equal "draft", @run.meeting_minutes.status
  end

  test "a rejected polling enqueue records a queue failure and retains the response ID" do
    replacement = ->(run:) { run.update!(status: "running", started_at: Time.current, provider_response_id: "resp_pending") }
    queue = Object.new
    def queue.perform_later(*) = false
    original = MinutesDraftGenerationJob.method(:set)
    MinutesDraftGenerationJob.define_singleton_method(:set) { |**| queue }

    with_stubbed_generate(replacement) { MinutesDraftGenerationJob.perform_now(@run) }

    assert_predicate @run.reload, :failed?
    assert_equal "queue_error", @run.error_category
    assert_equal "resp_pending", @run.provider_response_id
    assert_not_nil @run.completed_at
  ensure
    MinutesDraftGenerationJob.define_singleton_method(:set, original)
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
