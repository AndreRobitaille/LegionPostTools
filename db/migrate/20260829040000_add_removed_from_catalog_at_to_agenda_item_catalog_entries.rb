class AddRemovedFromCatalogAtToAgendaItemCatalogEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :agenda_item_catalog_entries, :removed_from_catalog_at, :datetime
    add_index :agenda_item_catalog_entries, [ :organization_id, :removed_from_catalog_at ],
      name: "idx_agenda_catalog_on_org_removal"
  end
end
