class CreateAgentAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :public_id, null: false
      t.string :secret_digest, null: false
      t.string :display_hint, null: false
      t.string :name, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.references :revoked_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :agent_access_tokens, :public_id, unique: true
    add_index :agent_access_tokens, :expires_at
    add_index :agent_access_tokens, :revoked_at
  end
end
