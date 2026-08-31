require "test_helper"

class Admin::JobsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Post Hall",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago, title: "July Membership")
    @manager = create_user_with("manage_minutes")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @transcript = MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @manager,
      retention_policy: "delete_after_acceptance",
      pasted_text: "The membership discussed the July agenda."
    ).call
  end

  test "minutes manager sees the durable AI run ledger and job controls" do
    failed_run = create_run!(status: "failed", error_category: "timeout")
    succeeded_run = create_run!(status: "succeeded")
    sign_in_as(@manager)

    get admin_jobs_path

    assert_response :success
    assert_select "h1", text: "Background jobs"
    assert_select ".jobs-health", count: 1
    assert_select ".jobs-health", text: /Worker health unavailable/
    assert_select ".jobs-run", count: 2
    assert_select ".jobs-run--failed", text: /July Membership.*did not finish in time/m
    assert_select "form[action=?]", retry_admin_job_path(failed_run)
    assert_select "form[action=?]", discard_admin_job_path(failed_run)
    assert_select "a[href=?]", admin_meeting_minutes_draft_run_path(@meeting, succeeded_run), text: "Review run"
  end

  test "needs attention excludes successful and discarded runs" do
    failed_run = create_run!(status: "failed", error_category: "timeout")
    discarded_run = create_run!(status: "failed", error_category: "provider_error")
    discarded_run.update!(discarded_at: Time.current, discarded_by: @manager)
    create_run!(status: "succeeded")
    sign_in_as(@manager)

    get admin_jobs_path(filter: "attention")

    assert_response :success
    assert_select ".jobs-run", count: 1
    assert_select ".jobs-run form[action=?]", retry_admin_job_path(failed_run)

    get admin_jobs_path(filter: "discarded")

    assert_response :success
    assert_select ".jobs-run", count: 1
    assert_select ".jobs-run form[action=?]", restore_admin_job_path(discarded_run)
  end

  test "retry creates and enqueues a linked run without changing the failure" do
    failed_run = create_run!(status: "failed", error_category: "timeout")
    sign_in_as(@manager)

    assert_difference -> { @minutes.draft_runs.count }, 1 do
      assert_enqueued_with(job: MinutesDraftGenerationJob) do
        post retry_admin_job_path(failed_run)
      end
    end

    retry_run = @minutes.draft_runs.recent.first
    assert_redirected_to admin_meeting_minutes_draft_run_path(@meeting, retry_run)
    assert_equal failed_run, retry_run.retry_of
    assert_equal @manager, retry_run.requested_by
    assert_predicate retry_run, :pending?
    assert_predicate failed_run.reload, :failed?
  end

  test "retry redirects to the existing active retry" do
    failed_run = create_run!(status: "failed", error_category: "timeout")
    retry_run = create_run!(status: "pending", retry_of: failed_run)
    sign_in_as(@manager)

    assert_no_difference -> { @minutes.draft_runs.count } do
      assert_no_enqueued_jobs do
        post retry_admin_job_path(failed_run)
      end
    end

    assert_redirected_to admin_meeting_minutes_draft_run_path(@meeting, retry_run)
  end

  test "discard and restore preserve the failed run" do
    failed_run = create_run!(status: "failed", error_category: "timeout")
    sign_in_as(@manager)

    assert_no_difference -> { MinutesDraftRun.count } do
      patch discard_admin_job_path(failed_run)
    end

    assert_redirected_to admin_jobs_path
    assert_predicate failed_run.reload, :discarded?
    assert_equal @manager, failed_run.discarded_by

    patch restore_admin_job_path(failed_run)

    assert_redirected_to admin_jobs_path(filter: "attention")
    assert_not_predicate failed_run.reload, :discarded?
    assert_nil failed_run.discarded_by
  end

  test "a user without minutes or settings authority cannot open the console" do
    member = create_user_with
    sign_in_as(member)

    get admin_jobs_path

    assert_redirected_to root_path
  end

  private

  def create_run!(status:, error_category: nil, retry_of: nil)
    @minutes.draft_runs.create!(
      meeting_transcript: @transcript,
      requested_by: @manager,
      provider: "openai",
      model: "gpt-5.6-sol",
      reasoning_effort: "high",
      text_verbosity: "medium",
      prompt_version: MinutesDrafting::Prompt::VERSION,
      prompt_sha256: MinutesDrafting::Prompt.sha256,
      schema_version: MinutesDrafting::Prompt::SCHEMA_VERSION,
      source_sha256: @transcript.sha256_digest,
      source_line_count: 1,
      status: status,
      error_category: error_category,
      retry_of: retry_of,
      started_at: status == "pending" ? nil : 2.minutes.ago,
      completed_at: status.in?(%w[succeeded failed]) ? Time.current : nil
    )
  end

  def create_user_with(*capabilities)
    person = Person.create!(first_name: "Jobs", last_name: SecureRandom.hex(3))
    user = User.create!(person: person, email_address: "jobs-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
