class CreateEndeavorTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :endeavor_tasks do |t|
      t.references :endeavor, null: false, foreign_key: true
      t.string :title, null: false
      t.date :due_on
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.datetime :completed_at
      t.references :completed_by, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :endeavor_tasks, "(completed_at IS NULL) = (completed_by_id IS NULL)", name: "endeavor_tasks_completion_provenance"
    add_index :endeavor_tasks, [ :endeavor_id, :due_on ]
  end
end
