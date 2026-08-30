class CreateStructuredMeetingMinutes < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_minutes do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :meeting, null: false, foreign_key: true, index: { unique: true }
      t.references :meeting_body, null: false, foreign_key: true
      t.references :meeting_type, null: true, foreign_key: true
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.string :location_name, null: false
      t.text :location_address
      t.string :status, null: false, default: "draft"
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :meeting_minutes, %i[organization_id starts_at]
    add_check_constraint :meeting_minutes,
      "status IN ('draft', 'approved', 'attested', 'accepted')",
      name: "meeting_minutes_status_check"

    create_table :minutes_sections do |t|
      t.references :meeting_minutes, null: false, foreign_key: true
      t.references :source_dated_agenda_section,
        null: true,
        foreign_key: { to_table: :dated_agenda_sections }
      t.string :title, null: false
      t.integer :position, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :minutes_sections,
      %i[meeting_minutes_id position],
      unique: true,
      name: "index_minutes_sections_on_minutes_and_position"
    add_check_constraint :minutes_sections, "position > 0", name: "minutes_sections_position_check"

    create_table :minutes_items do |t|
      t.references :minutes_section, null: false, foreign_key: true
      t.references :source_dated_agenda_item,
        null: true,
        foreign_key: { to_table: :dated_agenda_items }
      t.references :endeavor, null: true, foreign_key: true
      t.string :record_key, null: false
      t.string :title, null: false
      t.string :behavior_type, null: false
      t.integer :position, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :minutes_items,
      %i[minutes_section_id position],
      unique: true,
      name: "index_minutes_items_on_section_and_position"
    add_index :minutes_items, :record_key, unique: true
    add_check_constraint :minutes_items, "position > 0", name: "minutes_items_position_check"

    create_table :minutes_outcomes do |t|
      t.references :minutes_item, null: false, foreign_key: true
      t.string :kind, null: false
      t.text :text, null: false
      t.references :mover_person,
        null: true,
        foreign_key: { to_table: :people, on_delete: :nullify }
      t.string :mover_name
      t.references :seconder_person,
        null: true,
        foreign_key: { to_table: :people, on_delete: :nullify }
      t.string :seconder_name
      t.string :disposition, null: false, default: "not_recorded"
      t.string :vote_summary
      t.integer :position, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :minutes_outcomes,
      %i[minutes_item_id position],
      unique: true,
      name: "index_minutes_outcomes_on_item_and_position"
    add_check_constraint :minutes_outcomes,
      "kind IN ('motion', 'decision')",
      name: "minutes_outcomes_kind_check"
    add_check_constraint :minutes_outcomes,
      "disposition IN ('adopted', 'lost', 'withdrawn', 'postponed', 'referred', 'no_vote', 'not_recorded')",
      name: "minutes_outcomes_disposition_check"
    add_check_constraint :minutes_outcomes, "position > 0", name: "minutes_outcomes_position_check"

    create_table :minutes_attendance_entries do |t|
      t.references :meeting_minutes, null: false, foreign_key: true
      t.references :dated_agenda_roll_call_entry,
        null: true,
        foreign_key: true,
        index: { name: "index_minutes_attendance_on_agenda_roll_call" }
      t.references :position_title,
        null: true,
        foreign_key: { on_delete: :nullify }
      t.references :person,
        null: true,
        foreign_key: { on_delete: :nullify }
      t.string :office_name, null: false
      t.string :person_name
      t.string :status, null: false, default: "not_recorded"
      t.integer :position, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :minutes_attendance_entries,
      %i[meeting_minutes_id position],
      unique: true,
      name: "index_minutes_attendance_on_minutes_and_position"
    add_check_constraint :minutes_attendance_entries,
      "status IN ('present', 'absent', 'excused', 'vacant', 'not_recorded')",
      name: "minutes_attendance_status_check"
    add_check_constraint :minutes_attendance_entries,
      "position > 0",
      name: "minutes_attendance_position_check"
  end
end
