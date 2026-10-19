class CreateMinutesDistribution < ActiveRecord::Migration[8.1]
  def change
    create_table :minutes_distribution_settings do |t|
      t.references :organization, null: false, foreign_key: true, index: { unique: true }
      t.string :post_members_list_id
      t.string :minutes_recipients_list_id
      t.string :template_id
      t.string :reply_to
      t.jsonb :meeting_type_ids, null: false, default: []
      t.boolean :audiences_reviewed, null: false, default: false
      t.boolean :enabled, null: false, default: false
      t.timestamps
    end

    create_table :minutes_recipients do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :office, null: false
      t.string :email, null: false
      t.string :loops_contact_id
      t.string :enrolled_list_id
      t.string :enrollment_status, null: false, default: "not_enrolled"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :minutes_recipients, [ :organization_id, :email ]

    create_table :minutes_distributions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :meeting_minutes, null: false, foreign_key: true
      t.references :minutes_revision, null: false, foreign_key: true, index: { unique: true }
      t.string :content_digest, null: false
      t.string :state, null: false, default: "pending"
      t.boolean :corrected, null: false, default: false
      t.jsonb :document_context, null: false, default: {}
      t.string :filename
      t.string :pdf_sha256
      t.string :template_id
      t.string :minutes_list_id
      t.string :post_members_list_id
      t.string :reply_to
      t.string :error_message
      t.datetime :first_submitted_at
      t.timestamps
    end

    create_table :minutes_email_deliveries do |t|
      t.references :minutes_distribution, null: false, foreign_key: true
      t.string :email, null: false
      t.string :loops_contact_id
      t.jsonb :recipient_snapshot, null: false, default: []
      t.jsonb :variables, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.string :idempotency_key, null: false
      t.datetime :first_attempt_at
      t.datetime :accepted_at
      t.integer :attempt_count, null: false, default: 0
      t.string :error_message
      t.timestamps
    end
    add_index :minutes_email_deliveries, [ :minutes_distribution_id, :email ], unique: true, name: "index_minutes_deliveries_on_issue_and_email"
    add_index :minutes_email_deliveries, :idempotency_key, unique: true

    create_table :minutes_distribution_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :meeting_minutes, foreign_key: true
      t.references :minutes_recipient, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end

    create_table :loops_roster_enrollments do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :member_user_id, null: false
      t.string :email, null: false
      t.string :loops_contact_id, null: false
      t.string :list_id, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :loops_roster_enrollments, [ :organization_id, :email, :list_id ], unique: true, name: "index_loops_enrollments_on_organization_email_list"
    add_column :loops_roster_syncs, :list_results, :jsonb, null: false, default: {}
  end
end
