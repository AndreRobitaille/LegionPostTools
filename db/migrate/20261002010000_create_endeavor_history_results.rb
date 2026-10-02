class CreateEndeavorHistoryResults < ActiveRecord::Migration[8.1]
  def change
    create_table :endeavor_history_results do |t|
      t.references :endeavor, null: false, foreign_key: true
      t.references :endeavor_history_run, null: false, foreign_key: true
      t.string :stage, null: false
      t.string :fingerprint, null: false
      t.jsonb :input, null: false
      t.jsonb :candidate, null: false
      t.jsonb :verification, null: false
      t.jsonb :configuration, null: false
      t.timestamps
    end
    add_index :endeavor_history_results, [ :endeavor_id, :stage, :fingerprint ], name: "endeavor_history_result_reuse"
    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE FUNCTION protect_endeavor_history_result() RETURNS trigger AS $$
          BEGIN
            RAISE EXCEPTION 'verified endeavor history results are append-only';
          END;
          $$ LANGUAGE plpgsql;
          CREATE TRIGGER endeavor_history_results_immutable BEFORE UPDATE OR DELETE ON endeavor_history_results
          FOR EACH ROW EXECUTE FUNCTION protect_endeavor_history_result();
        SQL
      end
      direction.down { execute "DROP FUNCTION IF EXISTS protect_endeavor_history_result() CASCADE" }
    end
  end
end
