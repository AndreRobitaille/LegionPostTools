class ProtectMembershipApprovedMinutes < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION prevent_membership_approved_minutes_mutation()
      RETURNS trigger AS $$
      BEGIN
        IF OLD.status = 'membership_approved' THEN
          RAISE EXCEPTION 'membership-approved minutes are immutable';
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER meeting_minutes_membership_approved_immutable
      BEFORE UPDATE OR DELETE ON meeting_minutes
      FOR EACH ROW EXECUTE FUNCTION prevent_membership_approved_minutes_mutation();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS meeting_minutes_membership_approved_immutable ON meeting_minutes"
    execute "DROP FUNCTION IF EXISTS prevent_membership_approved_minutes_mutation()"
  end
end
