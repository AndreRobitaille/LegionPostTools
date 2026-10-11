class ProtectFinalMeetingContext < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION prevent_final_meeting_context_mutation()
      RETURNS trigger AS $$
      BEGIN
        IF ROW(NEW.organization_id, NEW.meeting_body_id, NEW.meeting_type_id,
               NEW.starts_at, NEW.title, NEW.location_name, NEW.location_address)
           IS DISTINCT FROM
           ROW(OLD.organization_id, OLD.meeting_body_id, OLD.meeting_type_id,
               OLD.starts_at, OLD.title, OLD.location_name, OLD.location_address)
           AND EXISTS (SELECT 1 FROM meeting_minutes
                       WHERE meeting_id = OLD.id AND status = 'membership_approved') THEN
          RAISE EXCEPTION 'This meeting''s date, title, body, type, and place are locked because its minutes are approved.';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER meetings_final_context_immutable
      BEFORE UPDATE ON meetings
      FOR EACH ROW EXECUTE FUNCTION prevent_final_meeting_context_mutation();

      CREATE FUNCTION lock_final_minutes_meeting_context()
      RETURNS trigger AS $$
      BEGIN
        IF NEW.status = 'membership_approved' THEN
          PERFORM 1 FROM meetings WHERE id = NEW.meeting_id FOR UPDATE;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER meeting_minutes_final_context_lock
      BEFORE INSERT OR UPDATE ON meeting_minutes
      FOR EACH ROW EXECUTE FUNCTION lock_final_minutes_meeting_context();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS meeting_minutes_final_context_lock ON meeting_minutes"
    execute "DROP FUNCTION IF EXISTS lock_final_minutes_meeting_context()"
    execute "DROP TRIGGER IF EXISTS meetings_final_context_immutable ON meetings"
    execute "DROP FUNCTION IF EXISTS prevent_final_meeting_context_mutation()"
  end
end
