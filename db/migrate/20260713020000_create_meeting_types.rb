class CreateMeetingTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_types do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.string :source_key
      t.string :source_label
      t.datetime :seeded_at

      t.timestamps
    end

    add_index :meeting_types, [ :organization_id, :slug ], unique: true
    add_index :meeting_types, [ :organization_id, :name ], unique: true
    add_index :meeting_types, [ :organization_id, :source_key ], unique: true, where: "source_key IS NOT NULL"
    add_index :meeting_types, [ :organization_id, :position ]
  end
end
