class CreateInstallations < ActiveRecord::Migration[8.1]
  def change
    create_table :installations do |t|
      t.string :singleton_key, null: false
      t.datetime :setup_completed_at

      t.timestamps
    end

    add_index :installations, :singleton_key, unique: true
  end
end
