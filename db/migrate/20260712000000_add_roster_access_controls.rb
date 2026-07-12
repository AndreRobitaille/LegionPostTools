class AddRosterAccessControls < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :login_access_override, :boolean, null: false, default: false
    add_column :users, :login_access_override_at, :datetime
    add_index :users, :login_access_override
  end
end
