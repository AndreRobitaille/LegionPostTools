class AddWebauthnIdToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :webauthn_id, :string

    # Backfill existing users with an opaque base64url handle (WebAuthn user id).
    User.reset_column_information
    User.where(webauthn_id: nil).find_each do |user|
      user.update_columns(webauthn_id: WebAuthn.generate_user_id)
    end

    change_column_null :users, :webauthn_id, false
    add_index :users, :webauthn_id, unique: true
  end

  def down
    remove_column :users, :webauthn_id
  end
end
