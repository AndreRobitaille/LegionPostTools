class CreateMinutesDraftRunsAndSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :minutes_draft_runs do |t|
      t.references :meeting_minutes, null: false, foreign_key: true
      t.references :meeting_transcript, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :provider, null: false
      t.string :model, null: false
      t.string :reasoning_effort, null: false
      t.string :prompt_version, null: false
      t.string :prompt_sha256, null: false
      t.string :schema_version, null: false
      t.string :source_sha256, null: false
      t.integer :source_line_count, null: false
      t.string :status, null: false, default: "pending"
      t.string :provider_response_id
      t.string :provider_request_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :reasoning_tokens
      t.integer :total_tokens
      t.string :error_category
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :minutes_draft_runs, %i[meeting_minutes_id created_at]
    add_check_constraint :minutes_draft_runs,
      "status IN ('pending', 'running', 'succeeded', 'failed')",
      name: "minutes_draft_runs_status_check"
    add_check_constraint :minutes_draft_runs,
      "source_line_count > 0",
      name: "minutes_draft_runs_source_line_count_check"

    create_table :minutes_draft_suggestions do |t|
      t.references :minutes_draft_run, null: false, foreign_key: true
      t.references :minutes_item, null: true, foreign_key: true
      t.references :minutes_attendance_entry, null: true, foreign_key: true
      t.references :minutes_section, null: true, foreign_key: true
      t.references :source_dated_agenda_item,
        null: true,
        foreign_key: { to_table: :dated_agenda_items }
      t.string :kind, null: false
      t.jsonb :payload, null: false, default: {}
      t.integer :source_start_line, null: false
      t.integer :source_end_line, null: false
      t.string :confidence, null: false
      t.jsonb :missing_facts, null: false, default: []
      t.string :review_state, null: false, default: "unreviewed"
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.string :applied_record_type
      t.bigint :applied_record_id
      t.timestamps
    end
    add_index :minutes_draft_suggestions,
      %i[minutes_draft_run_id review_state],
      name: "index_minutes_draft_suggestions_on_run_and_review_state"
    add_index :minutes_draft_suggestions,
      %i[applied_record_type applied_record_id],
      name: "index_minutes_draft_suggestions_on_applied_record"
    add_check_constraint :minutes_draft_suggestions,
      "kind IN ('item_summary', 'outcome', 'attendance', 'additional_item')",
      name: "minutes_draft_suggestions_kind_check"
    add_check_constraint :minutes_draft_suggestions,
      "confidence IN ('high', 'medium', 'low')",
      name: "minutes_draft_suggestions_confidence_check"
    add_check_constraint :minutes_draft_suggestions,
      "review_state IN ('unreviewed', 'used', 'edited', 'discarded')",
      name: "minutes_draft_suggestions_review_state_check"
    add_check_constraint :minutes_draft_suggestions,
      "source_start_line > 0 AND source_end_line >= source_start_line",
      name: "minutes_draft_suggestions_source_range_check"
  end
end
