require "test_helper"

class MeetingTranscriptTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Post Hall",
      timezone: "America/Chicago"
    )
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(
      organization: @organization,
      meeting_body: @meeting_body,
      starts_at: 1.day.ago
    )
    person = Person.create!(first_name: "Ada", last_name: "Adjutant")
    @adjutant = User.create!(person: person, email_address: "adjutant@example.com")
  end

  test "creates pasted transcript with normalized UTF-8 content and provenance" do
    transcript = MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @adjutant,
      retention_policy: "delete_after_acceptance",
      pasted_text: "\uFEFFFirst line\r\nSecond line\r\n"
    ).call

    assert_predicate transcript, :pasted_text?
    assert_equal "First line\nSecond line", transcript.content
    assert_equal transcript.content, transcript.source_text
    assert_equal transcript.content.bytesize, transcript.byte_size
    assert_equal Digest::SHA256.hexdigest(transcript.content), transcript.sha256_digest
    assert_equal "text/plain", transcript.media_type
    assert_equal @adjutant, transcript.created_by
    assert_not transcript.text_file.attached?
  end

  test "creates uploaded transcript while retaining the original text file" do
    upload = uploaded_text("First line\r\nSecond line\r\n", filename: "meeting.txt")

    transcript = MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @adjutant,
      retention_policy: "retain_restricted",
      text_upload: upload
    ).call

    assert_predicate transcript, :text_upload?
    assert_nil transcript.content
    assert_equal "meeting.txt", transcript.original_filename
    assert_equal "text/plain", transcript.media_type
    assert_predicate transcript.text_file, :attached?
    assert_equal "First line\nSecond line\n", transcript.source_text
    assert_equal Digest::SHA256.hexdigest("First line\r\nSecond line\r\n"), transcript.sha256_digest
  end

  test "requires exactly one source" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      MeetingTranscripts::Create.new(
        meeting: @meeting,
        created_by: @adjutant,
        retention_policy: "delete_after_acceptance"
      ).call
    end
    assert_includes error.record.errors[:base], "provide either pasted transcript text or one text file"

    error = assert_raises(ActiveRecord::RecordInvalid) do
      MeetingTranscripts::Create.new(
        meeting: @meeting,
        created_by: @adjutant,
        retention_policy: "delete_after_acceptance",
        pasted_text: "Pasted",
        text_upload: uploaded_text("Uploaded")
      ).call
    end
    assert_includes error.record.errors[:base], "provide either pasted transcript text or one text file"
  end

  test "rejects empty, invalid, oversized, and non-text sources" do
    assert_source_error("transcript is empty", pasted_text: " \n ")
    assert_source_error("transcript must be valid UTF-8 text", pasted_text: "\xFF".b)
    assert_source_error("transcript must be 5 MB or smaller", pasted_text: "a" * (MeetingTranscript::MAX_BYTES + 1))
    assert_source_error("upload a .txt transcript file", text_upload: uploaded_text("hello", filename: "meeting.srt"))
    assert_source_error(
      "upload must be a plain-text file",
      text_upload: uploaded_text("hello", filename: "meeting.txt", content_type: "application/pdf")
    )
  end

  test "does not replace an existing transcript" do
    first = MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @adjutant,
      retention_policy: "delete_after_acceptance",
      pasted_text: "Original source"
    ).call

    error = assert_raises(ActiveRecord::RecordInvalid) do
      MeetingTranscripts::Create.new(
        meeting: @meeting.reload,
        created_by: @adjutant,
        retention_policy: "retain_restricted",
        pasted_text: "Replacement source"
      ).call
    end

    assert_includes error.record.errors[:meeting], "already has a transcript source"
    assert_equal first.id, @meeting.reload.transcript.id
    assert_equal "Original source", @meeting.transcript.source_text
  end

  test "meeting and transcript must belong to the same organization" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "UTC")
    transcript = @meeting.build_transcript(
      organization: other,
      created_by: @adjutant,
      source_kind: "pasted_text",
      content: "Source",
      byte_size: 6,
      media_type: "text/plain",
      sha256_digest: Digest::SHA256.hexdigest("Source"),
      retention_policy: "delete_after_acceptance"
    )

    assert_not transcript.valid?
    assert_includes transcript.errors[:meeting], "must belong to the same organization"
  end

  test "purged source requires human provenance and cannot be read" do
    transcript = MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @adjutant,
      retention_policy: "delete_after_acceptance",
      pasted_text: "Original source"
    ).call
    transcript.content = nil
    transcript.purged_at = Time.current

    assert_not transcript.valid?
    assert_includes transcript.errors[:purged_by], "must be recorded when transcript source is purged"

    transcript.purged_by = @adjutant
    transcript.save!
    assert_not transcript.source_available?
    assert_raises(MeetingTranscript::SourcePurgedError) { transcript.source_text }
  end

  private

  def uploaded_text(content, filename: "meeting.txt", content_type: "text/plain")
    tempfile = Tempfile.new([ "meeting-transcript", ".txt" ])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind
    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: filename,
      type: content_type
    )
  end

  def assert_source_error(message, pasted_text: nil, text_upload: nil)
    error = assert_raises(ActiveRecord::RecordInvalid) do
      MeetingTranscripts::Create.new(
        meeting: @meeting,
        created_by: @adjutant,
        retention_policy: "delete_after_acceptance",
        pasted_text: pasted_text,
        text_upload: text_upload
      ).call
    end
    assert_includes error.record.errors[:base], message
  end
end
