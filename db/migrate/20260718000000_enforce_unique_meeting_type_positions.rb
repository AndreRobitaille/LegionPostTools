class EnforceUniqueMeetingTypePositions < ActiveRecord::Migration[8.1]
  def up
    lock_tables!
    normalize_meeting_type_positions!
    normalize_meeting_type_agenda_item_positions!

    remove_index :meeting_types, name: "index_meeting_types_on_organization_id_and_position"
    add_index :meeting_types, [ :organization_id, :position ], unique: true, name: "index_meeting_types_on_organization_id_and_position"

    remove_index :meeting_type_agenda_items, name: "index_mt_agenda_items_on_meeting_type_and_position"
    add_index :meeting_type_agenda_items, [ :meeting_type_id, :position ], unique: true, name: "index_mt_agenda_items_on_meeting_type_and_position"
  end

  def down
    remove_index :meeting_types, name: "index_meeting_types_on_organization_id_and_position"
    add_index :meeting_types, [ :organization_id, :position ], name: "index_meeting_types_on_organization_id_and_position"

    remove_index :meeting_type_agenda_items, name: "index_mt_agenda_items_on_meeting_type_and_position"
    add_index :meeting_type_agenda_items, [ :meeting_type_id, :position ], name: "index_mt_agenda_items_on_meeting_type_and_position"
  end

  private

  def normalize_meeting_type_positions!
    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY position, id) AS new_position
        FROM meeting_types
      )
      UPDATE meeting_types
      SET position = ranked.new_position
      FROM ranked
      WHERE meeting_types.id = ranked.id
    SQL
  end

  def normalize_meeting_type_agenda_item_positions!
    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY meeting_type_id ORDER BY position, id) AS new_position
        FROM meeting_type_agenda_items
      )
      UPDATE meeting_type_agenda_items
      SET position = ranked.new_position
      FROM ranked
      WHERE meeting_type_agenda_items.id = ranked.id
    SQL
  end

  def lock_tables!
    execute "LOCK TABLE meeting_types IN ACCESS EXCLUSIVE MODE"
    execute "LOCK TABLE meeting_type_agenda_items IN ACCESS EXCLUSIVE MODE"
  end
end
