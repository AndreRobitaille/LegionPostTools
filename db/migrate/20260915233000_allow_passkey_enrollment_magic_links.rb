class AllowPasskeyEnrollmentMagicLinks < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :magic_links, name: "magic_links_purpose_check"
    add_check_constraint :magic_links,
      "purpose IN ('sign_in', 'create_agent_access_token', 'official_minutes_action', 'enroll_passkey')",
      name: "magic_links_purpose_check"
  end

  def down
    if select_value("SELECT 1 FROM magic_links WHERE purpose = 'enroll_passkey' LIMIT 1")
      raise ActiveRecord::IrreversibleMigration,
        "Enrollment links exist. Roll back application code while keeping the expanded purpose constraint."
    end

    remove_check_constraint :magic_links, name: "magic_links_purpose_check"
    add_check_constraint :magic_links,
      "purpose IN ('sign_in', 'create_agent_access_token', 'official_minutes_action')",
      name: "magic_links_purpose_check"
  end
end
