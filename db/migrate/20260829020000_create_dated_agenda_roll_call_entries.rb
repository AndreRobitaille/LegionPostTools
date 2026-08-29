class CreateDatedAgendaRollCallEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :dated_agenda_roll_call_entries do |t|
      t.references :dated_agenda_item, null: false, foreign_key: true
      t.references :position_title, null: true, foreign_key: { on_delete: :nullify }
      t.references :person, null: true, foreign_key: { on_delete: :nullify }
      t.string :office_name, null: false
      t.string :person_name
      t.integer :position, null: false

      t.timestamps
    end

    add_index :dated_agenda_roll_call_entries,
      %i[dated_agenda_item_id position],
      unique: true,
      name: "idx_agenda_roll_call_item_position"
  end
end
