class ExtendMagicLinksForEmailCodes < ActiveRecord::Migration[8.1]
  def change
    add_column :magic_links, :code_digest, :string
    add_column :magic_links, :browser_challenge_digest, :string
    add_column :magic_links, :failed_attempts, :integer, default: 0, null: false
    add_column :magic_links, :purpose, :string, default: "sign_in", null: false
    add_reference :magic_links, :session, foreign_key: true
    add_index :magic_links, :browser_challenge_digest, unique: true
    add_check_constraint :magic_links,
      "purpose IN ('sign_in', 'create_agent_access_token')",
      name: "magic_links_purpose_check"

    add_column :sessions, :authenticated_at, :datetime
  end
end
