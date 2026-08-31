class AllowOfficialMinutesMagicLinks < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :magic_links, name: "magic_links_purpose_check"
    add_check_constraint :magic_links,
      "purpose IN ('sign_in', 'create_agent_access_token', 'official_minutes_action')",
      name: "magic_links_purpose_check"
  end
end
