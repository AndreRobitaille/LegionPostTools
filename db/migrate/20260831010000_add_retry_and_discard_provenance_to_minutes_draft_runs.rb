class AddRetryAndDiscardProvenanceToMinutesDraftRuns < ActiveRecord::Migration[8.1]
  def change
    add_reference :minutes_draft_runs, :retry_of,
      index: false,
      foreign_key: { to_table: :minutes_draft_runs }
    add_reference :minutes_draft_runs, :discarded_by,
      foreign_key: { to_table: :users, on_delete: :nullify }
    add_column :minutes_draft_runs, :discarded_at, :datetime

    add_index :minutes_draft_runs, :retry_of_id
    add_index :minutes_draft_runs, %i[status discarded_at]
    add_index :minutes_draft_runs, :retry_of_id,
      unique: true,
      where: "retry_of_id IS NOT NULL AND status IN ('pending', 'running')",
      name: "idx_one_active_minutes_draft_retry"
  end
end
