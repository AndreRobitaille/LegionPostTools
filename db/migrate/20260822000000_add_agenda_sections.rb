class AddAgendaSections < ActiveRecord::Migration[8.1]
  def up
    create_table :meeting_type_agenda_sections do |t|
      t.references :meeting_type, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :meeting_type_agenda_sections, [ :meeting_type_id, :position ], unique: true, name: "idx_mt_agenda_sections_position"
    add_index :meeting_type_agenda_sections, [ :meeting_type_id, :title ], unique: true, name: "idx_mt_agenda_sections_title"

    create_table :dated_agenda_sections do |t|
      t.references :dated_agenda, null: false, foreign_key: true
      t.references :meeting_type_agenda_section, foreign_key: true
      t.string :title, null: false
      t.integer :position, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :dated_agenda_sections, [ :dated_agenda_id, :position ], unique: true, name: "idx_dated_agenda_sections_position"
    add_index :dated_agenda_sections, [ :dated_agenda_id, :title ], unique: true, name: "idx_dated_agenda_sections_title"
    add_index :dated_agenda_sections, [ :dated_agenda_id, :meeting_type_agenda_section_id ], unique: true,
      where: "meeting_type_agenda_section_id IS NOT NULL", name: "idx_dated_sections_source"

    add_reference :meeting_type_agenda_items, :meeting_type_agenda_section, foreign_key: true, index: false
    add_reference :dated_agenda_items, :dated_agenda_section, foreign_key: true, index: false

    execute <<~SQL.squish
      INSERT INTO meeting_type_agenda_sections (meeting_type_id, title, position, created_at, updated_at)
      SELECT id, 'Order of Business', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM meeting_types
    SQL
    execute <<~SQL.squish
      UPDATE meeting_type_agenda_items AS items
      SET meeting_type_agenda_section_id = sections.id
      FROM meeting_type_agenda_sections AS sections
      WHERE sections.meeting_type_id = items.meeting_type_id
    SQL

    execute <<~SQL.squish
      INSERT INTO dated_agenda_sections (dated_agenda_id, title, position, lock_version, created_at, updated_at)
      SELECT id, 'Order of Business', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM dated_agendas
    SQL
    execute <<~SQL.squish
      UPDATE dated_agenda_items AS items
      SET dated_agenda_section_id = sections.id
      FROM dated_agenda_sections AS sections
      WHERE sections.dated_agenda_id = items.dated_agenda_id
    SQL

    change_column_null :meeting_type_agenda_items, :meeting_type_agenda_section_id, false
    change_column_null :dated_agenda_items, :dated_agenda_section_id, false

    remove_index :meeting_type_agenda_items, name: "index_mt_agenda_items_on_meeting_type_and_position"
    remove_index :dated_agenda_items, name: "index_dated_agenda_items_on_dated_agenda_id_and_position"
    add_index :meeting_type_agenda_items, [ :meeting_type_agenda_section_id, :position ], unique: true, name: "idx_mt_agenda_items_section_position"
    add_index :dated_agenda_items, [ :dated_agenda_section_id, :position ], unique: true, name: "idx_dated_agenda_items_section_position"
  end

  def down
    remove_index :meeting_type_agenda_items, name: "idx_mt_agenda_items_section_position"
    remove_index :dated_agenda_items, name: "idx_dated_agenda_items_section_position"

    resequence_items_for_parent(:meeting_type_agenda_items, :meeting_type_id)
    resequence_items_for_parent(:dated_agenda_items, :dated_agenda_id)

    add_index :meeting_type_agenda_items, [ :meeting_type_id, :position ], unique: true, name: "index_mt_agenda_items_on_meeting_type_and_position"
    add_index :dated_agenda_items, [ :dated_agenda_id, :position ], unique: true, name: "index_dated_agenda_items_on_dated_agenda_id_and_position"

    remove_reference :meeting_type_agenda_items, :meeting_type_agenda_section, foreign_key: true
    remove_reference :dated_agenda_items, :dated_agenda_section, foreign_key: true
    drop_table :dated_agenda_sections
    drop_table :meeting_type_agenda_sections
  end

  private

  def resequence_items_for_parent(table, parent_column)
    execute <<~SQL.squish
      WITH ordered AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY #{parent_column} ORDER BY position, id) AS new_position
        FROM #{table}
      )
      UPDATE #{table}
      SET position = ordered.new_position
      FROM ordered
      WHERE #{table}.id = ordered.id
    SQL
  end
end
