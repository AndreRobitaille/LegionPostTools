class CreatePositionCapabilityGrants < ActiveRecord::Migration[8.1]
  ROLE_CAPABILITIES = {
    "Commander" => %w[manage_agendas approve_minutes],
    "Adjutant" => %w[manage_agendas manage_minutes attest_minutes]
  }.freeze

  ALLOWED_CAPABILITIES = %w[
    manage_people
    manage_meeting_bodies
    manage_agendas
    manage_minutes
    approve_minutes
    attest_minutes
    record_acceptance_motions
    view_internal_records
  ].freeze

  def up
    create_table :position_capability_grants do |t|
      t.references :position_title, null: false, foreign_key: { on_delete: :cascade }
      t.string :capability, null: false

      t.timestamps
    end

    add_index :position_capability_grants,
      %i[position_title_id capability],
      unique: true,
      name: "index_position_capabilities_on_title_and_capability"
    add_check_constraint :position_capability_grants,
      "capability IN (#{ALLOWED_CAPABILITIES.map { |capability| connection.quote(capability) }.join(', ')})",
      name: "position_capability_grants_capability_check"

    ROLE_CAPABILITIES.each do |title_name, capabilities|
      capabilities.each do |capability|
        execute <<~SQL.squish
          INSERT INTO position_capability_grants
            (position_title_id, capability, created_at, updated_at)
          SELECT position_titles.id, #{connection.quote(capability)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          FROM position_titles
          INNER JOIN organizations ON organizations.id = position_titles.organization_id
          WHERE organizations.unit_type = 'american_legion_post'
            AND position_titles.name = #{connection.quote(title_name)}
          ON CONFLICT (position_title_id, capability) DO NOTHING
        SQL
      end
    end

    # Existing officeholders may have received the same duties as permanent
    # user grants before position-based access existed. Once the role policy is
    # present, those duplicates must be removed or they would survive the role's
    # end date and defeat the automatic lifecycle.
    execute <<~SQL.squish
      DELETE FROM permission_grants
      USING users, position_assignments, position_titles, position_capability_grants
      WHERE permission_grants.user_id = users.id
        AND users.person_id = position_assignments.person_id
        AND position_assignments.position_title_id = position_titles.id
        AND position_capability_grants.position_title_id = position_titles.id
        AND permission_grants.capability = position_capability_grants.capability
        AND position_titles.active = TRUE
        AND position_assignments.starts_on <= CURRENT_DATE
        AND (position_assignments.ends_on IS NULL OR position_assignments.ends_on >= CURRENT_DATE)
    SQL
  end

  def down
    # Preserve current effective access if the schema is rolled back. The
    # previous version represented these duties as permanent user grants.
    execute <<~SQL.squish
      INSERT INTO permission_grants (user_id, capability, created_at, updated_at)
      SELECT users.id, position_capability_grants.capability, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users
      INNER JOIN position_assignments ON position_assignments.person_id = users.person_id
      INNER JOIN position_titles ON position_titles.id = position_assignments.position_title_id
      INNER JOIN position_capability_grants ON position_capability_grants.position_title_id = position_titles.id
      WHERE position_titles.active = TRUE
        AND position_assignments.starts_on <= CURRENT_DATE
        AND (position_assignments.ends_on IS NULL OR position_assignments.ends_on >= CURRENT_DATE)
      ON CONFLICT (user_id, capability) DO NOTHING
    SQL

    drop_table :position_capability_grants
  end
end
