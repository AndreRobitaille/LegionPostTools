class AddBuddyCareUpdates < ActiveRecord::Migration[8.1]
  def up
    create_table :buddy_care_updates do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.string :status, null: false
      t.text :notes, null: false
      t.date :follow_up_on
      t.integer :revision, null: false
      t.string :submission_key, null: false
      t.datetime :created_at, null: false
    end
    add_index :buddy_care_updates, [ :organization_id, :person_id, :revision ], unique: true
    add_index :buddy_care_updates, [ :organization_id, :submission_key ], unique: true
    add_check_constraint :buddy_care_updates, "revision > 0", name: "positive_buddy_care_revision"
    add_check_constraint :buddy_care_updates, "status IN ('needs_attention', 'cleared')", name: "buddy_care_status"
    add_check_constraint :buddy_care_updates,
      "status != 'needs_attention' OR (assigned_to_id IS NOT NULL AND follow_up_on IS NOT NULL)", name: "buddy_care_follow_up"
    execute "CREATE TRIGGER preserve_buddy_evidence BEFORE UPDATE OR DELETE ON buddy_care_updates FOR EACH ROW EXECUTE FUNCTION preserve_buddy_evidence()"
  end

  def down
    drop_table :buddy_care_updates
  end
end
