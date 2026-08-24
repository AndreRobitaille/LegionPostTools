class CreateLoopsRosterSyncs < ActiveRecord::Migration[8.1]
  def change
    create_table :loops_roster_syncs do |t|
      t.references :roster_import, null: false, foreign_key: true
      t.references :requested_by, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :status, null: false, default: "queued"
      t.integer :eligible_count, null: false, default: 0
      t.integer :synced_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.integer :missing_email_count, null: false, default: 0
      t.integer :invalid_email_count, null: false, default: 0
      t.integer :shared_email_count, null: false, default: 0
      t.jsonb :failures, null: false, default: []
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :loops_roster_syncs, :created_at
    add_index :loops_roster_syncs, :status,
      unique: true,
      where: "status IN ('queued', 'running')",
      name: "idx_one_active_loops_roster_sync"
  end
end
