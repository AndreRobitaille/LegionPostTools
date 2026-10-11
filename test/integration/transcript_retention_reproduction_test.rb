require "test_helper"
require "tempfile"

# Regression for #79, extended from the original missing-deletion reproduction.
# Invoke the real scheduled job; only synthetic test records/storage are used.
class TranscriptRetentionReproductionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    assert Rails.env.test?
    travel_to Time.utc(2026, 10, 1, 18)
    @organization = Organization.create!(name: "Synthetic retention Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @commander = officer("Commander", %w[approve_minutes record_minutes_approval])
    @adjutant = officer("Adjutant", %w[attest_minutes])
    clear_enqueued_jobs
    clear_performed_jobs
  end

  teardown do
    @upload&.close!
    @storage&.delete(@storage_key) if @storage_key && @storage.exist?(@storage_key)
  end

  %w[pasted_text text_upload].each do |kind|
    %w[delete_after_acceptance retain_restricted].each do |policy|
      test "ordinary final approval keeps or deletes #{kind} under #{policy} after the stated recovery window" do
        meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 60.days.ago)
        transcript = create_source(meeting, kind, policy)
        original_text = transcript.source_text
        metadata = transcript.attributes.slice("created_by_id", "retention_policy", "source_kind", "byte_size", "sha256_digest")
        if kind == "text_upload"
          @storage = transcript.text_file.blob.service
          @storage_key = transcript.text_file.blob.key
          blob_id = transcript.text_file.blob.id
          assert @storage.exist?(@storage_key)
        end
        minutes = attested_minutes_for(meeting)
        approving = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.hour.ago)
        approval = minutes.record_membership_approval_with_confirmation!(confirmation: confirmation(minutes, @commander,
          "record_membership_approval", approving_meeting_id: approving.id, disposition: "approved_as_presented"))
        assert_predicate minutes.reload, :membership_approved?
        assert_not minutes.editable?
        assert_equal approving.id, approval.approving_meeting_id
        assert_equal @commander.id, approval.recorded_by_id
        assert_equal @adjutant.id, minutes.current_revision.attestation.attested_by_id
        assert_includes minutes.member_revision.payload.to_json, "Twelve families received assistance."
        assert_equal 0, MinutesDraftRun.count
        official = official_graph(minutes)

        travel_to approval.recorded_at + 29.days
        assert_not MeetingTranscripts::Purge.new(transcript:).call
        PurgeMeetingTranscriptsJob.perform_now
        assert_predicate transcript.reload, :source_available?
        assert_equal original_text, transcript.source_text
        assert_equal official, official_graph(minutes)

        travel_to approval.recorded_at + 31.days
        PurgeMeetingTranscriptsJob.perform_now
        assert_equal official, official_graph(minutes)
        assert_equal metadata, transcript.reload.attributes.slice(*metadata.keys)
        if policy == "retain_restricted"
          assert_not MeetingTranscripts::Purge.new(transcript:).call
          assert_predicate transcript, :source_available?
          assert_equal original_text, transcript.source_text
          assert_nil transcript.purged_at
          assert_nil transcript.purge_started_at
          assert_nil transcript.scheduled_purge_at
        else
          assert_not transcript.source_available?, "delete-after-acceptance source remains available after ordinary final approval plus 31 days"
          assert_nil transcript.content
          assert_not transcript.text_file.attached?
          assert_not ActiveStorage::Blob.exists?(blob_id) if blob_id
          assert_not @storage.exist?(@storage_key) if @storage_key
          assert_not_nil transcript.purged_at
          assert_equal "transcript_retention", transcript.purged_by_service
          assert_nil transcript.purged_by_id
          completion = transcript.attributes
          PurgeMeetingTranscriptsJob.perform_now
          assert_equal completion, transcript.reload.attributes
          assert_raises(MeetingTranscript::SourcePurgedError) { transcript.source_text }
        end
      end
    end
  end

  %w[pasted_text text_upload].each do |kind|
    test "a #{kind} source attached to old final minutes keeps the original finalization deadline" do
      meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 60.days.ago)
      minutes = attested_minutes_for(meeting)
      approving = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.hour.ago)
      minutes.record_membership_approval_with_confirmation!(confirmation: confirmation(minutes, @commander,
        "record_membership_approval", approving_meeting_id: approving.id, disposition: "approved_as_presented"))
      official = official_graph(minutes)
      travel_to Time.utc(2026, 11, 1, 18)
      transcript = create_source(meeting, kind, "delete_after_acceptance")
      assert_predicate transcript, :source_available?
      assert_equal Time.utc(2026, 10, 31, 18), transcript.scheduled_purge_at
      PurgeMeetingTranscriptsJob.perform_now
      assert_removed(transcript)
      assert_equal Time.current, transcript.purged_at
      assert_equal official, official_graph(minutes)
    end
  end

  %w[pasted_text text_upload].each do |kind|
    %w[delete_after_acceptance retain_restricted].each do |policy|
      test "pending corrections keep #{kind} until final attestation plus thirty days under #{policy}" do
        meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 60.days.ago)
        transcript = create_source(meeting, kind, policy)
        original_text = transcript.source_text
        metadata = source_metadata(transcript)
        minutes = attested_minutes_for(meeting)
        first_attestation = minutes.current_revision.attestation.attributes
        approving = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.hour.ago)
        decision_at = Time.current
        minutes.record_membership_approval_with_confirmation!(confirmation: confirmation(minutes, @commander,
          "record_membership_approval", approving_meeting_id: approving.id, disposition: "approved_as_corrected",
          corrections_pending: true, factual_note: "Correct the fictional report title."))
        assert_nil minutes.reload.membership_approval
        assert_predicate minutes, :draft?
        assert_nil transcript.reload.scheduled_purge_at
        pending = minutes.pending_correction_approval.attributes

        travel_to Time.utc(2026, 11, 1, 18)
        PurgeMeetingTranscriptsJob.perform_now
        assert_predicate transcript.reload, :source_available?
        assert_equal original_text, transcript.source_text
        assert_nil transcript.purge_started_at
        assert_equal pending, minutes.pending_correction_approval.attributes
        minutes.update!(title: "Corrected fictional report")
        minutes.attest_with_confirmation!(confirmation: confirmation(minutes, @adjutant, "attest"))
        assert_predicate minutes.reload, :membership_approved?
        assert_equal decision_at, minutes.membership_approval.recorded_at
        assert_equal Time.utc(2026, 11, 1, 18), minutes.membership_approval.minutes_revision.attestation.attested_at
        assert_equal first_attestation, MinutesAttestation.find(first_attestation.fetch("id")).attributes
        assert_equal pending, MinutesLifecycleEvent.find(pending.fetch("id")).attributes
        assert_equal "Corrected fictional report", minutes.member_revision.payload.fetch("title")
        official = official_graph(minutes)
        expected_due = Time.utc(2026, 12, 1, 18)
        if policy == "delete_after_acceptance"
          assert_equal expected_due, transcript.reload.scheduled_purge_at
        else
          assert_nil transcript.reload.scheduled_purge_at
        end

        travel_to expected_due - 1
        PurgeMeetingTranscriptsJob.perform_now
        assert_predicate transcript.reload, :source_available?
        assert_equal original_text, transcript.source_text
        assert_nil transcript.purge_started_at
        assert @storage.exist?(@storage_key) if @storage_key
        travel_to expected_due
        PurgeMeetingTranscriptsJob.perform_now
        assert_equal official, official_graph(minutes)
        assert_equal metadata, source_metadata(transcript.reload)
        if policy == "retain_restricted"
          assert_predicate transcript, :source_available?
          assert_equal original_text, transcript.source_text
          assert_nil transcript.purged_at
          assert_nil transcript.purge_started_at
          assert @storage.exist?(@storage_key) if @storage_key
        else
          assert_removed(transcript)
          assert_equal expected_due, transcript.purge_started_at
          assert_equal expected_due, transcript.purged_at
          completed = transcript.attributes
          travel_to expected_due + 7.days
          PurgeMeetingTranscriptsJob.perform_now
          assert_equal completed, transcript.reload.attributes
          assert_equal official, official_graph(minutes)
        end
      end
    end
  end

  test "storage failure keeps the locator blocks reads and retries without harming another due source" do
    transcript, minutes = final_source("text_upload")
    other, other_minutes = final_source("pasted_text")
    official = [ official_graph(minutes), official_graph(other_minutes) ]
    metadata = source_metadata(transcript)
    storage = @storage
    key = @storage_key
    blob_id = transcript.text_file.blob.id
    original_delete = storage.method(:delete)
    travel_to Time.utc(2026, 11, 1, 18)
    with_method_override(storage, :delete, ->(requested_key) { requested_key == key ? raise(IOError, "Fictional sensitive storage error") : original_delete.call(requested_key) }) do
      error = assert_raises(PurgeMeetingTranscriptsJob::BatchRemovalError) { PurgeMeetingTranscriptsJob.perform_now }
      assert_includes error.message, transcript.id.to_s
      assert_not_includes error.message, "sensitive storage error"
      assert_nil error.cause
    end
    assert_not transcript.reload.source_available?
    assert_equal Time.current, transcript.purge_started_at
    assert_nil transcript.purged_at
    assert_nil transcript.purged_by_service
    assert transcript.text_file.attached?
    assert ActiveStorage::Blob.exists?(blob_id)
    assert storage.exist?(key)
    assert_equal metadata, source_metadata(transcript)
    assert_removed(other)
    assert_equal official, [ official_graph(minutes), official_graph(other_minutes) ]
    assert_raises(MeetingTranscript::SourcePurgedError) { transcript.source_text }
    travel_to Time.utc(2026, 11, 1, 19)
    PurgeMeetingTranscriptsJob.perform_now
    assert_removed(transcript)
    assert_equal Time.utc(2026, 11, 1, 18), transcript.purge_started_at
    assert_equal Time.current, transcript.purged_at
    assert_equal metadata, source_metadata(transcript)
    assert_equal official, [ official_graph(minutes), official_graph(other_minutes) ]
  end

  test "a completion transaction failure after storage deletion preserves its locator for reconciliation" do
    transcript, minutes = final_source("text_upload")
    official = official_graph(minutes)
    metadata = source_metadata(transcript)
    blob_id = transcript.text_file.blob.id
    travel_to Time.utc(2026, 11, 1, 18)
    original_update = transcript.method(:update!)
    replacement = ->(**attributes) do
      if attributes.key?(:purged_at)
        raise ActiveRecord::RecordInvalid, transcript
      end
      original_update.call(**attributes)
    end
    with_method_override(transcript, :update!, replacement) do
      assert_raises(ActiveRecord::RecordInvalid) { MeetingTranscripts::Purge.new(transcript:).call }
    end
    assert_not @storage.exist?(@storage_key), "the real storage object was removed before the database failure"
    assert ActiveStorage::Blob.exists?(blob_id), "rollback must retain the locator"
    assert transcript.reload.text_file.attached?
    assert_not transcript.source_available?
    assert_nil transcript.purged_at
    assert_nil transcript.purged_by_service
    assert_equal metadata, source_metadata(transcript)
    assert_equal official, official_graph(minutes)
    PurgeMeetingTranscriptsJob.perform_now
    assert_removed(transcript)
    assert_equal metadata, source_metadata(transcript)
    assert_equal official, official_graph(minutes)
  end

  test "a shared upload fails safely without deleting the other attachment" do
    transcript, minutes = final_source("text_upload")
    blob = transcript.text_file.blob
    other_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago)
    other = MeetingTranscripts::Create.new(meeting: other_meeting, created_by: @adjutant, retention_policy: "retain_restricted", pasted_text: "Other fictional source").call
    shared = ActiveStorage::Attachment.create!(name: "text_file", record: other, blob:)
    official = official_graph(minutes)
    travel_to Time.utc(2026, 11, 1, 18)
    assert_raises(PurgeMeetingTranscriptsJob::BatchRemovalError) { PurgeMeetingTranscriptsJob.perform_now }
    assert_nil transcript.reload.purged_at
    assert_not transcript.source_available?
    assert @storage.exist?(@storage_key)
    assert ActiveStorage::Attachment.exists?(shared.id)
    assert_equal "Other fictional source", other.reload.content
    assert_equal official, official_graph(minutes)
    shared.delete
    PurgeMeetingTranscriptsJob.perform_now
    assert_removed(transcript)
    assert_equal "Other fictional source", other.reload.source_text
    assert_equal official, official_graph(minutes)
  end

  private

  def with_method_override(object, name, replacement)
    original = object.method(name)
    singleton_method = object.singleton_class.instance_methods(false).include?(name)
    object.define_singleton_method(name, replacement)
    yield
  ensure
    if singleton_method
      object.define_singleton_method(name, original)
    else
      object.singleton_class.remove_method(name)
    end
  end

  def attested_minutes_for(meeting)
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    minutes.sections.first.items.create!(title: "Community report", behavior_type: "report_slot", position: 1,
      body: "Twelve families received assistance. This is fictional test wording.")
    minutes.approve_with_confirmation!(confirmation: confirmation(minutes, @commander, "approve"))
    minutes.attest_with_confirmation!(confirmation: confirmation(minutes, @adjutant, "attest"))
    minutes
  end

  def final_source(kind, policy: "delete_after_acceptance")
    meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 60.days.ago)
    transcript = create_source(meeting, kind, policy)
    minutes = attested_minutes_for(meeting)
    approving = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.hour.ago)
    minutes.record_membership_approval_with_confirmation!(confirmation: confirmation(minutes, @commander,
      "record_membership_approval", approving_meeting_id: approving.id, disposition: "approved_as_presented"))
    [ transcript, minutes ]
  end

  def source_metadata(transcript)
    transcript.attributes.slice("organization_id", "meeting_id", "created_by_id", "source_kind", "retention_policy", "original_filename", "byte_size", "media_type", "sha256_digest")
  end

  def assert_removed(transcript)
    assert_not transcript.reload.source_available?
    assert_nil transcript.content
    assert_not transcript.text_file.attached?
    if transcript.text_upload?
      assert_not @storage.exist?(@storage_key)
      assert_not ActiveStorage::Blob.exists?(@blob_id)
      assert_not ActiveStorage::Attachment.exists?(record: transcript, name: "text_file")
    end
    assert_equal "transcript_retention", transcript.purged_by_service
    assert_nil transcript.purged_by_id
    assert_not_nil transcript.purge_started_at
    assert_not_nil transcript.purged_at
    assert_raises(MeetingTranscript::SourcePurgedError) { transcript.source_text }
  end

  def officer(name, capabilities)
    user = User.create!(person: Person.create!(first_name: "Synthetic", last_name: name), email_address: "#{name.downcase}-retention@example.test")
    position = @organization.position_titles.create!(name:, display_order: @organization.position_titles.count + 1, active: true)
    position.position_assignments.create!(person: user.person, starts_on: 1.year.ago.to_date)
    capabilities.each { |capability| user.permission_grants.create!(capability:) }
    user
  end

  def create_source(meeting, kind, policy)
    input = if kind == "pasted_text"
      { pasted_text: "Synthetic adjutant: twelve families received assistance.\n" }
    else
      @upload = Tempfile.new([ "synthetic-retention", ".txt" ])
      @upload.binmode
      @upload.write("\uFEFFSynthetic adjutant: José reported twelve families.\r\n")
      @upload.rewind
      { text_upload: ActionDispatch::Http::UploadedFile.new(tempfile: @upload, filename: "synthetic-retention.txt", type: "text/plain") }
    end
    transcript = MeetingTranscripts::Create.new(meeting:, created_by: @adjutant, retention_policy: policy, **input).call
    if kind == "text_upload"
      @storage = transcript.text_file.blob.service
      @storage_key = transcript.text_file.blob.key
      @blob_id = transcript.text_file.blob.id
    end
    transcript
  end

  def confirmation(minutes, user, action, **action_payload)
    OfficialActionConfirmation.record_external!(minutes:, user:, action:, action_payload:,
      evidence_note: "Fictional test-only written confirmation; no live official record.")
  end

  def official_graph(minutes)
    revisions = minutes.revisions.order(:id)
    [ minutes.reload.attributes, minutes.revision_payload,
      minutes.sections.order(:id).map(&:attributes), minutes.items.order(:id).map(&:attributes),
      minutes.attendance_entries.order(:id).map(&:attributes), revisions.map(&:attributes),
      MinutesAttestation.where(minutes_revision_id: revisions.select(:id)).order(:id).map(&:attributes),
      minutes.lifecycle_events.order(:id).map(&:attributes), minutes.membership_approval.attributes,
      minutes.official_action_confirmations.order(:id).map(&:attributes) ]
  end
end
