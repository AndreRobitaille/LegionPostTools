class GrantCommandersMinutesManagement < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO position_capability_grants
        (position_title_id, capability, created_at, updated_at)
      SELECT position_titles.id, 'manage_minutes', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM position_titles
      INNER JOIN organizations ON organizations.id = position_titles.organization_id
      WHERE organizations.unit_type = 'american_legion_post'
        AND position_titles.name = 'Commander'
      ON CONFLICT (position_title_id, capability) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "A Commander may have relied on this minutes-management authority."
  end
end
