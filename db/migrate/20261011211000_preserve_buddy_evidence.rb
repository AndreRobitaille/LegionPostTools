class PreserveBuddyEvidence < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :buddy_address_source_version, :bigint, null: false, default: 0
    execute <<~SQL
      CREATE FUNCTION advance_buddy_address_source() RETURNS trigger AS $$
      BEGIN
        IF NEW.roster_address IS DISTINCT FROM OLD.roster_address OR
           NEW.roster_imported_at IS DISTINCT FROM OLD.roster_imported_at THEN
          NEW.buddy_address_source_version := OLD.buddy_address_source_version + 1;
        ELSE
          NEW.buddy_address_source_version := OLD.buddy_address_source_version;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER advance_buddy_address_source
        BEFORE UPDATE ON people FOR EACH ROW EXECUTE FUNCTION advance_buddy_address_source();

      CREATE FUNCTION preserve_buddy_evidence() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'Buddy Check evidence is append-only';
      END;
      $$ LANGUAGE plpgsql;
    SQL
    %w[buddy_operations buddy_attendance_registers buddy_address_reviews].each do |table|
      execute "CREATE TRIGGER preserve_buddy_evidence BEFORE UPDATE OR DELETE ON #{table} FOR EACH ROW EXECUTE FUNCTION preserve_buddy_evidence()"
    end
    execute <<~SQL
      CREATE TRIGGER preserve_buddy_contacts BEFORE UPDATE OR DELETE ON membership_contacts
        FOR EACH ROW WHEN (OLD.purpose = 'buddy_check') EXECUTE FUNCTION preserve_buddy_evidence();
    SQL
  end

  def down
    execute "DROP TRIGGER preserve_buddy_contacts ON membership_contacts"
    %w[buddy_operations buddy_attendance_registers buddy_address_reviews].each do |table|
      execute "DROP TRIGGER preserve_buddy_evidence ON #{table}"
    end
    execute "DROP FUNCTION preserve_buddy_evidence()"
    execute "DROP TRIGGER advance_buddy_address_source ON people"
    execute "DROP FUNCTION advance_buddy_address_source()"
    remove_column :people, :buddy_address_source_version
  end
end
