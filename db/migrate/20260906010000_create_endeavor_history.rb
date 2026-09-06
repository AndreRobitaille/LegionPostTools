class CreateEndeavorHistory < ActiveRecord::Migration[8.1]
  def change
    add_column :endeavors, :history_withdrawn, :boolean, null: false, default: false
    add_column :endeavors, :history_generation, :integer, null: false, default: 0

    create_table :endeavor_history_guidances do |t|
      t.references :endeavor, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.bigint :agent_access_token_id
      t.timestamps
    end
    create_table :endeavor_history_runs do |t|
      t.references :endeavor, null: false, foreign_key: true
      t.references :requested_by, foreign_key: { to_table: :users }
      t.bigint :agent_access_token_id
      t.string :status, null: false, default: "pending"
      t.string :fingerprint, null: false
      t.jsonb :manifest, null: false, default: {}
      t.jsonb :steps, null: false, default: []
      t.string :error_category
      t.datetime :started_at
      t.datetime :heartbeat_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :endeavor_history_runs, :endeavor_id, unique: true,
      where: "status IN ('pending', 'running')", name: "one_active_endeavor_history_run"
    add_index :endeavor_history_runs, [ :endeavor_id, :fingerprint ]
    add_check_constraint :endeavor_history_runs,
      "status IN ('pending', 'running', 'succeeded', 'failed', 'superseded')", name: "endeavor_history_run_status"

    create_table :endeavor_history_editions do |t|
      t.references :endeavor, null: false, foreign_key: true
      t.references :endeavor_history_run, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :payload, null: false
      t.jsonb :manifest, null: false
      t.string :sha256, null: false
      t.timestamps
    end
    create_table :endeavor_source_links do |t|
      t.references :endeavor, null: false, foreign_key: true
      t.references :endeavor_history_edition, null: false, foreign_key: true
      t.references :minutes_revision, null: false, foreign_key: true
      t.string :record_key, null: false
      t.jsonb :source_ids, null: false
      t.timestamps
    end
    add_index :endeavor_source_links, [ :endeavor_history_edition_id, :minutes_revision_id, :record_key ],
      unique: true, name: "unique_endeavor_edition_source"
    create_table :endeavor_history_events do |t|
      t.references :endeavor, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :endeavor_history_run, foreign_key: true
      t.bigint :agent_access_token_id
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE FUNCTION protect_endeavor_history() RETURNS trigger AS $$
          BEGIN
            RAISE EXCEPTION 'endeavor history evidence is append-only';
          END;
          $$ LANGUAGE plpgsql;
        SQL
        %w[endeavor_history_guidances endeavor_history_editions endeavor_source_links endeavor_history_events].each do |table|
          execute "CREATE TRIGGER #{table}_immutable BEFORE UPDATE OR DELETE ON #{table} FOR EACH ROW EXECUTE FUNCTION protect_endeavor_history()"
        end
        execute <<~SQL
          CREATE FUNCTION protect_completed_endeavor_history_run() RETURNS trigger AS $$
          BEGIN
            IF TG_OP = 'DELETE' OR OLD.status IN ('succeeded', 'failed', 'superseded') OR
               NEW.manifest IS DISTINCT FROM OLD.manifest OR NEW.fingerprint IS DISTINCT FROM OLD.fingerprint OR
               NEW.endeavor_id IS DISTINCT FROM OLD.endeavor_id OR NEW.requested_by_id IS DISTINCT FROM OLD.requested_by_id THEN
              RAISE EXCEPTION 'endeavor history run inputs and completed results are immutable';
            END IF;
            RETURN NEW;
          END;
          $$ LANGUAGE plpgsql;
          CREATE TRIGGER endeavor_history_run_protected BEFORE UPDATE OR DELETE ON endeavor_history_runs
          FOR EACH ROW EXECUTE FUNCTION protect_completed_endeavor_history_run();
        SQL
      end
      direction.down do
        execute "DROP FUNCTION IF EXISTS protect_endeavor_history() CASCADE"
        execute "DROP FUNCTION IF EXISTS protect_completed_endeavor_history_run() CASCADE"
      end
    end
  end
end
