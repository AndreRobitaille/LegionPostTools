class AddDisabledReasonToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :disabled_reason, :string
    add_column :users, :disabled_reason_detail, :string
    add_index :users, :disabled_reason

    execute <<~SQL.squish
      UPDATE users
      SET disabled_reason = CASE
            WHEN users.login_access_override = TRUE THEN 'manual'
            WHEN people.roster_removed_at IS NOT NULL THEN 'roster_removed'
            WHEN LOWER(TRIM(COALESCE(people.roster_member_status, ''))) IN ('expired', 'deceased') THEN 'roster_status'
            ELSE 'manual'
          END,
          disabled_reason_detail = CASE
            WHEN users.login_access_override = FALSE
              AND people.roster_removed_at IS NULL
              AND LOWER(TRIM(COALESCE(people.roster_member_status, ''))) IN ('expired', 'deceased')
            THEN LOWER(TRIM(people.roster_member_status))
            ELSE NULL
          END
      FROM people
      WHERE users.person_id = people.id
        AND users.disabled_at IS NOT NULL
    SQL
  end

  def down
    remove_index :users, :disabled_reason
    remove_column :users, :disabled_reason_detail
    remove_column :users, :disabled_reason
  end
end
