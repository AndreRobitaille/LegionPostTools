class CreateAgendaItemCatalogEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :agenda_item_catalog_entries do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :summary, null: false, default: ""
      t.string :category, null: false
      t.string :behavior_type, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.string :source_key
      t.string :source_label
      t.datetime :seeded_at

      t.timestamps
    end

    add_index :agenda_item_catalog_entries, [ :organization_id, :slug ], unique: true
    add_index :agenda_item_catalog_entries, [ :organization_id, :source_key ], unique: true, where: "source_key IS NOT NULL"
    add_index :agenda_item_catalog_entries, [ :organization_id, :category, :position ], name: "idx_agenda_catalog_on_org_category_position"
  end
end
