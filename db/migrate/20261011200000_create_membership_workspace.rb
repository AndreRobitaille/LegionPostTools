class CreateMembershipWorkspace < ActiveRecord::Migration[8.1]
  def change
    create_table :membership_drives do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.integer :membership_year, null: false
      t.string :purpose, null: false, default: "renewal"
      t.text :script
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.datetime :closed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    create_table :membership_assignments do |t|
      t.references :membership_drive, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :assigned_to, null: false, foreign_key: { to_table: :users }
      t.references :assigned_by, null: false, foreign_key: { to_table: :users }
      t.date :expires_on, null: false
      t.datetime :revoked_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :membership_assignments, [ :membership_drive_id, :person_id ], unique: true, where: "revoked_at IS NULL", name: "index_membership_assignments_on_drive_and_person"

    create_table :membership_contacts do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.references :membership_assignment, foreign_key: true
      t.integer :membership_year, null: false
      t.string :purpose, null: false
      t.date :occurred_on, null: false
      t.string :channel, null: false
      t.string :outcome, null: false
      t.text :notes
      t.date :follow_up_on
      t.string :paper_reference
      t.string :submission_key, null: false
      t.timestamps
    end
    add_index :membership_contacts, :submission_key, unique: true
    add_index :membership_contacts, :paper_reference, unique: true
    add_index :membership_contacts, [ :person_id, :membership_year, :occurred_on ]

    create_table :membership_dues_records do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :person, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.references :reverses_record, foreign_key: { to_table: :membership_dues_records }, index: { unique: true }
      t.integer :membership_year, null: false
      t.string :kind, null: false
      t.date :received_on, null: false
      t.decimal :amount, precision: 12, scale: 2
      t.string :reference
      t.text :notes
      t.string :submission_key, null: false
      t.timestamps
    end
    add_index :membership_dues_records, :submission_key, unique: true

    create_table :membership_summaries do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.integer :membership_year, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :submission_key, null: false
      t.timestamps
    end
    add_index :membership_summaries, :submission_key, unique: true
  end
end
