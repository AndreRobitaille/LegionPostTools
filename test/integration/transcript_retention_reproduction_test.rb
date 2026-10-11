require "test_helper"
require "tempfile"

# Draft reproduction for #79. It intentionally remains on an unmerged branch.
# This runs the existing approval/enqueued-job path, not a nonexistent recurrence.
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
        minutes = MeetingMinutes.create_from_meeting!(meeting:)
        minutes.sections.first.items.create!(title: "Community report", behavior_type: "report_slot", position: 1,
          body: "Twelve families received assistance. This is fictional test wording.")
        minutes.approve_with_confirmation!(confirmation: confirmation(minutes, @commander, "approve"))
        minutes.attest_with_confirmation!(confirmation: confirmation(minutes, @adjutant, "attest"))
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
        perform_enqueued_jobs(at: Time.current)
        assert_predicate transcript.reload, :source_available?
        assert_equal original_text, transcript.source_text
        assert_equal official, official_graph(minutes)

        travel_to approval.recorded_at + 31.days
        perform_enqueued_jobs(at: Time.current)
        assert_equal official, official_graph(minutes)
        assert_equal metadata, transcript.reload.attributes.slice(*metadata.keys)
        puts({ kind:, policy:, source_available: transcript.source_available?, pasted_content_present: transcript.content.present?,
          attachment_present: transcript.text_file.attached?, storage_present: @storage_key ? @storage.exist?(@storage_key) : false,
          queued_job_classes: enqueued_jobs.map { |job| job[:job].name }, performed_job_classes: performed_jobs.map { |job| job[:job].name } }.to_json)

        if policy == "retain_restricted"
          assert_predicate transcript, :source_available?
          assert_equal original_text, transcript.source_text
          assert_nil transcript.purged_at
        else
          assert_not transcript.source_available?, "delete-after-acceptance source remains available after ordinary final approval plus 31 days"
          assert_nil transcript.content
          assert_not transcript.text_file.attached?
          assert_not ActiveStorage::Blob.exists?(blob_id) if blob_id
          assert_not @storage.exist?(@storage_key) if @storage_key
          assert_not_nil transcript.purged_at
          assert_raises(MeetingTranscript::SourcePurgedError) { transcript.source_text }
        end
      end
    end
  end

  private

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
    MeetingTranscripts::Create.new(meeting:, created_by: @adjutant, retention_policy: policy, **input).call
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
