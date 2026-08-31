class AddMinutesApprovalAndAttestation < ActiveRecord::Migration[8.1]
  def change
    create_table :official_action_confirmations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :session, null: true, foreign_key: true
      t.references :agent_access_token, null: true, foreign_key: true
      t.references :meeting_minutes, null: false, foreign_key: true
      t.string :action, null: false
      t.integer :record_lock_version, null: false
      t.string :content_digest, null: false
      t.string :confirmation_method, null: false, default: "in_app"
      t.text :evidence_note
      t.datetime :expires_at, null: false
      t.datetime :confirmed_at
      t.datetime :consumed_at
      t.timestamps
    end
    add_check_constraint :official_action_confirmations,
      "action IN ('approve', 'attest')",
      name: "official_action_confirmations_action_check"
    add_check_constraint :official_action_confirmations,
      "confirmation_method IN ('in_app', 'delegated_agent', 'external_written_confirmation')",
      name: "official_action_confirmations_method_check"

    create_table :minutes_revisions do |t|
      t.references :meeting_minutes, null: false, foreign_key: true
      t.integer :number, null: false
      t.jsonb :payload, null: false
      t.string :sha256, null: false
      t.references :approved_by, null: false, foreign_key: { to_table: :users }
      t.string :approver_name, null: false
      t.string :approver_office, null: false
      t.datetime :approved_at, null: false
      t.timestamps
    end
    add_index :minutes_revisions, %i[meeting_minutes_id number], unique: true
    add_index :minutes_revisions, %i[meeting_minutes_id sha256]
    add_check_constraint :minutes_revisions, "number > 0", name: "minutes_revisions_number_check"

    add_reference :meeting_minutes,
      :current_revision,
      null: true,
      foreign_key: { to_table: :minutes_revisions }

    create_table :minutes_attestations do |t|
      t.references :minutes_revision, null: false, foreign_key: true, index: { unique: true }
      t.references :attested_by, null: false, foreign_key: { to_table: :users }
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.references :official_action_confirmation, null: false, foreign_key: true, index: { unique: true }
      t.string :attester_name, null: false
      t.string :attester_office, null: false
      t.datetime :attested_at, null: false
      t.timestamps
    end

    create_table :minutes_lifecycle_events do |t|
      t.references :meeting_minutes, null: false, foreign_key: true
      t.references :minutes_revision, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.references :official_action_confirmation, null: false, foreign_key: true, index: { unique: true }
      t.string :event_type, null: false
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.string :actor_name, null: false
      t.string :actor_office, null: false
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_check_constraint :minutes_lifecycle_events,
      "event_type IN ('approved', 'attested')",
      name: "minutes_lifecycle_events_type_check"

    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE FUNCTION prevent_minutes_official_record_mutation()
          RETURNS trigger AS $$
          BEGIN
            RAISE EXCEPTION 'official minutes records are append-only';
          END;
          $$ LANGUAGE plpgsql;

          CREATE TRIGGER minutes_revisions_append_only
          BEFORE UPDATE OR DELETE ON minutes_revisions
          FOR EACH ROW EXECUTE FUNCTION prevent_minutes_official_record_mutation();

          CREATE TRIGGER minutes_attestations_append_only
          BEFORE UPDATE OR DELETE ON minutes_attestations
          FOR EACH ROW EXECUTE FUNCTION prevent_minutes_official_record_mutation();

          CREATE TRIGGER minutes_lifecycle_events_append_only
          BEFORE UPDATE OR DELETE ON minutes_lifecycle_events
          FOR EACH ROW EXECUTE FUNCTION prevent_minutes_official_record_mutation();
        SQL
      end

      direction.down do
        execute "DROP FUNCTION IF EXISTS prevent_minutes_official_record_mutation() CASCADE"
      end
    end
  end
end
