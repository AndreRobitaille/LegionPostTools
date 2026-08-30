class CreateMeetingTranscripts < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_transcripts do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :meeting, null: false, foreign_key: true, index: { unique: true }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :source_kind, null: false
      t.text :content
      t.string :original_filename
      t.bigint :byte_size, null: false
      t.string :media_type, null: false
      t.string :sha256_digest, null: false
      t.string :retention_policy, null: false, default: "delete_after_acceptance"
      t.datetime :purge_scheduled_at
      t.datetime :purged_at
      t.references :purged_by, null: true, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :meeting_transcripts, :sha256_digest
    add_check_constraint :meeting_transcripts,
      "source_kind IN ('pasted_text', 'text_upload')",
      name: "meeting_transcripts_source_kind_check"
    add_check_constraint :meeting_transcripts,
      "retention_policy IN ('delete_after_acceptance', 'retain_restricted')",
      name: "meeting_transcripts_retention_policy_check"
    add_check_constraint :meeting_transcripts,
      "byte_size >= 0",
      name: "meeting_transcripts_byte_size_check"
  end
end
