class AddAutomaticTranscriptPurgeProvenance < ActiveRecord::Migration[8.1]
  def change
    add_column :meeting_transcripts, :purge_started_at, :datetime
    add_column :meeting_transcripts, :purged_by_service, :string
    add_check_constraint :meeting_transcripts,
      "purged_by_service IS NULL OR (purged_by_service = 'transcript_retention' AND purged_by_id IS NULL AND purged_at IS NOT NULL AND purge_started_at IS NOT NULL)",
      name: "meeting_transcripts_automatic_purge_provenance"
  end
end
