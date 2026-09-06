class CreateCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :endeavor, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description, null: false, default: ""
      t.string :location, null: false, default: ""
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.boolean :all_day, null: false, default: false
      t.string :visibility, null: false, default: "members"
      t.boolean :cancelled, null: false, default: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :calendar_events, [ :organization_id, :starts_at ]
    add_check_constraint :calendar_events, "visibility IN ('members', 'public')", name: "calendar_events_visibility"
    add_check_constraint :calendar_events, "ends_at IS NULL OR ends_at >= starts_at", name: "calendar_events_date_order"
  end
end
