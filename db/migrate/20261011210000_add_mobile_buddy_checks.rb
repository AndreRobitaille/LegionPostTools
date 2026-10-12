class AddMobileBuddyChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_applications do |t|
      t.string :name, null: false
      t.string :uid, null: false
      t.string :secret
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.boolean :confidential, null: false, default: false
      t.timestamps
    end
    add_index :oauth_applications, :uid, unique: true
    create_table :oauth_access_grants do |t|
      t.references :resource_owner, null: false, foreign_key: { to_table: :users }
      t.references :application, null: false, foreign_key: { to_table: :oauth_applications }
      t.string :token, null: false
      t.integer :expires_in, null: false
      t.text :redirect_uri, null: false
      t.datetime :created_at, null: false
      t.datetime :revoked_at
      t.string :scopes, null: false, default: ""
      t.string :code_challenge
      t.string :code_challenge_method
    end
    add_index :oauth_access_grants, :token, unique: true
    create_table :oauth_access_tokens do |t|
      t.references :resource_owner, foreign_key: { to_table: :users }
      t.references :application, foreign_key: { to_table: :oauth_applications }
      t.string :token, null: false
      t.string :refresh_token
      t.integer :expires_in
      t.datetime :revoked_at
      t.datetime :created_at, null: false
      t.string :scopes
    end
    add_index :oauth_access_tokens, :token, unique: true
    add_index :oauth_access_tokens, :refresh_token, unique: true

    add_column :membership_contacts, :occurred_at, :datetime
    add_column :membership_contacts, :entry_zone, :string
    add_column :membership_contacts, :revision, :integer, null: false, default: 1
    add_reference :membership_contacts, :supersedes_contact, foreign_key: { to_table: :membership_contacts }, index: { unique: true }
    add_reference :membership_contacts, :logical_contact, foreign_key: { to_table: :membership_contacts }
    add_check_constraint :membership_contacts, "(occurred_at IS NULL) = (entry_zone IS NULL)", name: "contact_precision_pair"
    add_check_constraint :membership_contacts, "revision > 0", name: "positive_contact_revision"

    create_table :buddy_operations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.uuid :operation_id, null: false
      t.string :fingerprint, null: false
      t.jsonb :receipt, null: false
      t.timestamps
    end
    add_index :buddy_operations, [ :organization_id, :user_id, :operation_id ], unique: true

    create_table :buddy_follow_ups do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :membership_contact, foreign_key: true
      t.datetime :due_at, null: false
      t.string :entry_zone, null: false
      t.string :status, null: false, default: "open"
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    create_table :buddy_snoozes do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.datetime :until_at, null: false
      t.datetime :cancelled_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    create_table :buddy_attendance_registers do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.integer :revision, null: false
      t.boolean :complete, null: false, default: false
      t.jsonb :entries, null: false, default: {}
      t.text :coverage_note, null: false
      t.datetime :created_at, null: false
    end
    add_index :buddy_attendance_registers, [ :meeting_id, :revision ], unique: true
    create_table :buddy_address_reviews do |t|
      t.references :person, null: false, foreign_key: true
      t.references :reviewed_by, null: false, foreign_key: { to_table: :users }
      t.string :source_digest, null: false
      t.jsonb :components, null: false, default: {}
      t.text :source_note, null: false
      t.datetime :created_at, null: false
    end
  end
end
