class AddRosterRemovalTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :roster_removed_at, :datetime
    add_index :people, :roster_removed_at
    add_column :roster_imports, :removed_count, :integer, null: false, default: 0
  end
end
