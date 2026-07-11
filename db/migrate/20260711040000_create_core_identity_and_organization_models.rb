class CreateCoreIdentityAndOrganizationModels < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email_address
      t.string :phone_number
      t.string :member_number
      t.text :notes
      t.timestamps
    end
    add_index :people, :email_address
    add_index :people, :member_number

    create_table :users do |t|
      t.references :person, null: false, foreign_key: true, index: { unique: true }
      t.string :email_address, null: false
      t.datetime :email_verified_at
      t.datetime :disabled_at
      t.timestamps
    end
    add_index :users, :email_address, unique: true

    create_table :organizations do |t|
      t.string :name, null: false
      t.string :unit_type, null: false
      t.string :unit_number
      t.string :timezone, null: false, default: "America/Chicago"
      t.string :default_location_name
      t.text :default_location_address
      t.timestamps
    end

    create_table :position_titles do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :display_order, null: false, default: 0
      t.boolean :required_by_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :position_titles, %i[organization_id name], unique: true

    create_table :position_assignments do |t|
      t.references :person, null: false, foreign_key: true
      t.references :position_title, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on
      t.timestamps
    end
    add_index :position_assignments, %i[person_id position_title_id starts_on], name: "idx_position_assignments_identity"
    add_check_constraint :position_assignments, "ends_on IS NULL OR ends_on >= starts_on", name: "position_assignments_date_order_check"

    create_table :permission_grants do |t|
      t.references :user, null: false, foreign_key: true
      t.string :capability, null: false
      t.timestamps
    end
    add_index :permission_grants, %i[user_id capability], unique: true
    add_check_constraint :permission_grants, "capability IN ('manage_settings', 'manage_people', 'manage_meeting_bodies', 'manage_agendas', 'manage_minutes', 'approve_minutes', 'attest_minutes', 'record_acceptance_motions', 'view_internal_records')", name: "permission_grants_capability_check"

    create_table :meeting_bodies do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :default_location_name
      t.text :default_location_address
      t.string :default_distribution, null: false, default: "print"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :meeting_bodies, %i[organization_id slug], unique: true
  end
end
