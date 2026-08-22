class CreateTrackedItems < ActiveRecord::Migration[8.1]
  def change
    create_table :tracked_items do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :meeting_body, null: true, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :completed_by, null: true, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :summary, null: false, default: ""
      t.string :importance, null: false, default: "standard"
      t.date :raise_by_on
      t.string :status, null: false, default: "active"
      t.datetime :completed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :tracked_items, [ :organization_id, :status ]
    add_index :tracked_items, [ :organization_id, :raise_by_on ]
    add_check_constraint :tracked_items, "importance IN ('standard', 'important')", name: "tracked_items_importance_check"
    add_check_constraint :tracked_items, "status IN ('active', 'completed')", name: "tracked_items_status_check"

    create_table :tracked_item_updates do |t|
      t.references :tracked_item, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_reference :dated_agenda_items, :tracked_item, null: true, foreign_key: true
    add_index :dated_agenda_items, [ :dated_agenda_id, :tracked_item_id ],
      unique: true,
      where: "tracked_item_id IS NOT NULL",
      name: "idx_dated_agenda_items_agenda_tracked_item"
  end
end
