class RenameTrackedItemsToEndeavors < ActiveRecord::Migration[8.1]
  def up
    rename_table :tracked_items, :endeavors
    rename_table :tracked_item_updates, :endeavor_updates
    rename_column :endeavor_updates, :tracked_item_id, :endeavor_id
    rename_column :dated_agenda_items, :tracked_item_id, :endeavor_id

    rename_index :dated_agenda_items,
      :idx_dated_agenda_items_agenda_tracked_item,
      :idx_dated_agenda_items_agenda_endeavor
    rename_constraint :endeavors, :tracked_items_importance_check, :endeavors_importance_check
    rename_constraint :endeavors, :tracked_items_status_check, :endeavors_status_check

    execute <<~SQL.squish
      UPDATE action_text_rich_texts
      SET record_type = CASE record_type
        WHEN 'TrackedItem' THEN 'Endeavor'
        WHEN 'TrackedItemUpdate' THEN 'EndeavorUpdate'
      END
      WHERE record_type IN ('TrackedItem', 'TrackedItemUpdate')
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE action_text_rich_texts
      SET record_type = CASE record_type
        WHEN 'Endeavor' THEN 'TrackedItem'
        WHEN 'EndeavorUpdate' THEN 'TrackedItemUpdate'
      END
      WHERE record_type IN ('Endeavor', 'EndeavorUpdate')
    SQL

    rename_constraint :endeavors, :endeavors_importance_check, :tracked_items_importance_check
    rename_constraint :endeavors, :endeavors_status_check, :tracked_items_status_check
    rename_index :dated_agenda_items,
      :idx_dated_agenda_items_agenda_endeavor,
      :idx_dated_agenda_items_agenda_tracked_item

    rename_column :dated_agenda_items, :endeavor_id, :tracked_item_id
    rename_column :endeavor_updates, :endeavor_id, :tracked_item_id
    rename_table :endeavor_updates, :tracked_item_updates
    rename_table :endeavors, :tracked_items
  end

  private

  def rename_constraint(table, from, to)
    execute <<~SQL.squish
      ALTER TABLE #{quote_table_name(table)}
      RENAME CONSTRAINT #{quote_column_name(from)} TO #{quote_column_name(to)}
    SQL
  end
end
