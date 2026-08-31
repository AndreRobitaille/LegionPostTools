require "test_helper"

class MinutesDraftRunTest < ActiveSupport::TestCase
  test "retry and discard provenance must describe the same durable run" do
    organization = Organization.create!(name: "Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: organization, meeting_body: body, starts_at: 1.day.ago)
    other_meeting = create_meeting!(organization: organization, meeting_body: body, starts_at: 1.month.ago)
    person = Person.create!(first_name: "Test", last_name: "Officer")
    user = User.create!(person: person, email_address: "officer@example.com", email_verified_at: Time.current)
    minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)
    other_minutes = MeetingMinutes.create_from_meeting!(meeting: other_meeting)
    transcript = transcript_for(meeting, user)
    other_transcript = transcript_for(other_meeting, user)
    original = run_for(minutes, transcript, user)

    wrong_retry = run_for(other_minutes, other_transcript, user, retry_of: original)
    assert_not wrong_retry.valid?
    assert_includes wrong_retry.errors[:retry_of], "must belong to the same minutes record"

    incomplete_discard = run_for(minutes, transcript, user, discarded_by: user)
    assert_not incomplete_discard.valid?
    assert_includes incomplete_discard.errors[:discarded_at], "must be recorded when a discarding person is present"
  end

  private

  def transcript_for(meeting, user)
    MeetingTranscripts::Create.new(
      meeting: meeting,
      created_by: user,
      retention_policy: "delete_after_acceptance",
      pasted_text: "A valid transcript source."
    ).call
  end

  def run_for(minutes, transcript, user, **attributes)
    MinutesDraftRun.new({
      meeting_minutes: minutes,
      meeting_transcript: transcript,
      requested_by: user,
      provider: "openai",
      model: "gpt-5.6-sol",
      reasoning_effort: "high",
      text_verbosity: "medium",
      prompt_version: "test",
      prompt_sha256: "a" * 64,
      schema_version: "test",
      source_sha256: transcript.sha256_digest,
      source_line_count: 1,
      status: "failed"
    }.merge(attributes))
  end
end
