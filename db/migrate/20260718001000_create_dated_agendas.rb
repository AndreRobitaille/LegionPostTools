class CreateDatedAgendas < ActiveRecord::Migration[8.1]
  def change
    create_table :dated_agendas do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :meeting_body, null: false, foreign_key: true
      t.references :meeting_type, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.references :published_by, foreign_key: { to_table: :users }
      t.datetime :published_at
      t.references :reopened_by, foreign_key: { to_table: :users }
      t.datetime :reopened_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :dated_agendas, [ :organization_id, :starts_at ]
    add_index :dated_agendas, [ :organization_id, :meeting_body_id, :meeting_type_id, :starts_at ], name: "index_dated_agendas_on_org_body_type_and_starts_at"
    add_index :dated_agendas, [ :organization_id, :status ]

    create_table :dated_agenda_items do |t|
      t.references :dated_agenda, null: false, foreign_key: true
      t.references :meeting_type_agenda_item, foreign_key: true
      t.references :agenda_item_catalog_entry, null: true, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :title, null: false
      t.text :summary, null: false, default: ""
      t.string :behavior_type, null: false
      t.boolean :active, null: false, default: true
      t.bigint :source_meeting_type_agenda_item_id
      t.string :source_key
      t.string :source_label
      t.datetime :seeded_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :dated_agenda_items, [ :dated_agenda_id, :position ], unique: true
    add_index :dated_agenda_items, [ :dated_agenda_id, :agenda_item_catalog_entry_id ], unique: true, name: "index_dated_agenda_items_on_agenda_and_catalog_entry"
    add_index :dated_agenda_items, [ :dated_agenda_id, :meeting_type_agenda_item_id ], unique: true, where: "meeting_type_agenda_item_id IS NOT NULL", name: "index_dated_agenda_items_on_agenda_and_mt_item"
    add_index :dated_agenda_items, [ :dated_agenda_id, :source_key ], unique: true, where: "source_key IS NOT NULL", name: "index_dated_agenda_items_on_agenda_and_source_key"
  end
end
