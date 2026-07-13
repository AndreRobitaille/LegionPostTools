class CreateMeetingTypeAgendaItems < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_type_agenda_items do |t|
      t.references :meeting_type, null: false, foreign_key: true
      t.references :agenda_item_catalog_entry, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :title, null: false
      t.text :summary, null: false, default: ""
      t.boolean :active, null: false, default: true
      t.string :source_key
      t.string :source_label
      t.datetime :seeded_at

      t.timestamps
    end

    add_index :meeting_type_agenda_items, [ :meeting_type_id, :position ], name: "index_mt_agenda_items_on_meeting_type_and_position"
    add_index :meeting_type_agenda_items, [ :meeting_type_id, :agenda_item_catalog_entry_id ], unique: true, name: "index_mt_agenda_items_on_type_and_catalog_entry"
    add_index :meeting_type_agenda_items, [ :meeting_type_id, :source_key ], unique: true, where: "source_key IS NOT NULL", name: "index_mt_agenda_items_on_type_and_source_key"
  end
end
