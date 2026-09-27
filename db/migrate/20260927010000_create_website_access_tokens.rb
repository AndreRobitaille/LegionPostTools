class CreateWebsiteAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :website_access_tokens do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :revoked_by, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :public_id, null: false
      t.string :secret_digest, null: false
      t.string :display_hint, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :website_access_tokens, :public_id, unique: true
  end
end
