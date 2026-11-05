class CreateEndeavorHistoryDiscoveries < ActiveRecord::Migration[8.1]
  def change
    create_table :endeavor_history_discoveries do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :fingerprint, null: false
      t.jsonb :input, null: false
      t.references :owner_run, foreign_key: { to_table: :endeavor_history_runs }
      t.references :result, foreign_key: { to_table: :endeavor_history_results }
      t.string :error_category
      t.timestamps
    end
    add_index :endeavor_history_discoveries, [ :organization_id, :fingerprint ], unique: true, name: "unique_endeavor_history_discovery"
    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE FUNCTION protect_endeavor_history_discovery() RETURNS trigger AS $$
          BEGIN
            IF TG_OP = 'DELETE' OR OLD.result_id IS NOT NULL OR
              NEW.organization_id IS DISTINCT FROM OLD.organization_id OR
              NEW.fingerprint IS DISTINCT FROM OLD.fingerprint OR
              NEW.input IS DISTINCT FROM OLD.input THEN
              RAISE EXCEPTION 'shared discovery inputs and accepted results are immutable';
            END IF;
            RETURN NEW;
          END;
          $$ LANGUAGE plpgsql;
          CREATE TRIGGER endeavor_history_discoveries_immutable BEFORE UPDATE OR DELETE ON endeavor_history_discoveries
          FOR EACH ROW EXECUTE FUNCTION protect_endeavor_history_discovery();
        SQL
      end
      direction.down { execute "DROP FUNCTION IF EXISTS protect_endeavor_history_discovery() CASCADE" }
    end
  end
end
