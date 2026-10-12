class AddMobileRememberedSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :mobile_remembered_sessions do |t|
      t.uuid :public_id, null: false
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :application, null: false, foreign_key: { to_table: :oauth_applications }
      t.datetime :authorized_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :revocation_reason
      t.timestamps
    end
    add_index :mobile_remembered_sessions, :public_id, unique: true
    add_check_constraint :mobile_remembered_sessions,
      "expires_at = authorized_at + interval '15552000 seconds'", name: "fixed_mobile_session_lifetime"
    add_check_constraint :mobile_remembered_sessions,
      "(revoked_at IS NULL) = (revocation_reason IS NULL)", name: "mobile_session_revocation_pair"
    add_reference :oauth_access_grants, :remembered_session, foreign_key: { to_table: :mobile_remembered_sessions }
    add_reference :oauth_access_tokens, :remembered_session, foreign_key: { to_table: :mobile_remembered_sessions }

    create_table :mobile_refresh_credentials do |t|
      t.references :remembered_session, null: false, foreign_key: { to_table: :mobile_remembered_sessions }
      t.string :token_digest, null: false
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :mobile_refresh_credentials, :token_digest, unique: true
    add_index :mobile_refresh_credentials, :remembered_session_id, unique: true,
      where: "consumed_at IS NULL", name: "one_current_mobile_refresh_credential"

    create_table :mobile_token_exchanges do |t|
      t.references :remembered_session, null: false, foreign_key: { to_table: :mobile_remembered_sessions }
      t.references :authorization_grant, foreign_key: { to_table: :oauth_access_grants }, index: { unique: true }
      t.references :refresh_credential, foreign_key: { to_table: :mobile_refresh_credentials }, index: { unique: true }
      t.references :issued_refresh_credential, null: false, foreign_key: { to_table: :mobile_refresh_credentials }
      t.references :access_token, null: false, foreign_key: { to_table: :oauth_access_tokens }
      t.uuid :exchange_id, null: false
      t.string :request_digest, null: false
      t.datetime :recoverable_until, null: false
      t.text :response_ciphertext
      t.timestamps
    end
    add_check_constraint :mobile_token_exchanges,
      "(authorization_grant_id IS NULL) <> (refresh_credential_id IS NULL)", name: "one_mobile_exchange_source"
    add_index :mobile_token_exchanges, :recoverable_until
    add_index :mobile_token_exchanges, [ :remembered_session_id, :exchange_id ], unique: true,
      name: "unique_mobile_exchange_id_per_session"
  end
end
