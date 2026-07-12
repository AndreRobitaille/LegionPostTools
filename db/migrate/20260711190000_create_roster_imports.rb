class CreateRosterImports < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_imports do |t|
      t.string :uploaded_filename, null: false
      t.string :status, null: false, default: "completed"
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :unchanged_count, null: false, default: 0
      t.integer :problem_count, null: false, default: 0
      t.jsonb :summary, null: false, default: {}
      t.datetime :imported_at, null: false

      t.timestamps
    end

    add_index :roster_imports, [ :status, :imported_at ]
  end
end
