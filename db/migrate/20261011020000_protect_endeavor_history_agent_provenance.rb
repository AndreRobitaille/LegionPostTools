class ProtectEndeavorHistoryAgentProvenance < ActiveRecord::Migration[8.1]
  def up
    replace_guard(include_agent_token: true)
  end

  def down
    replace_guard(include_agent_token: false)
  end

  private

  def replace_guard(include_agent_token:)
    agent_token_condition = include_agent_token ? "OR NEW.agent_access_token_id IS DISTINCT FROM OLD.agent_access_token_id" : ""
    execute <<~SQL
      CREATE OR REPLACE FUNCTION protect_completed_endeavor_history_run() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' OR OLD.status IN ('succeeded', 'failed', 'superseded') OR
           NEW.manifest IS DISTINCT FROM OLD.manifest OR NEW.fingerprint IS DISTINCT FROM OLD.fingerprint OR
           NEW.endeavor_id IS DISTINCT FROM OLD.endeavor_id OR NEW.requested_by_id IS DISTINCT FROM OLD.requested_by_id
           #{agent_token_condition} THEN
          RAISE EXCEPTION 'endeavor history run inputs and completed results are immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end
end
