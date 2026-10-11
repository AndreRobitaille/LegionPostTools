require "test_helper"
require "fugit"

class PurgeMeetingTranscriptsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "the configured hourly retention task parses and executes the actual background job" do
    task = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true)
      .fetch("production").fetch("purge_meeting_transcripts")
    job_class = task.fetch("class").constantize
    assert_equal PurgeMeetingTranscriptsJob, job_class
    assert_equal "background", task.fetch("queue")
    schedule = Fugit.parse(task.fetch("schedule"), multi: :fail)
    first = schedule.next_time(Time.utc(2026, 10, 1, 18, 36)).to_t
    assert_equal Time.utc(2026, 10, 1, 18, 37), first
    assert_equal Time.utc(2026, 10, 1, 19, 37), schedule.next_time(first).to_t
    assert_enqueued_with(job: job_class, queue: "background") do
      job_class.set(queue: task.fetch("queue")).perform_later
    end
    assert_performed_with(job: job_class) { perform_enqueued_jobs(only: job_class) }
  end
end
