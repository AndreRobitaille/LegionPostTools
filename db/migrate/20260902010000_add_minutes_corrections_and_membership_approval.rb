class AddMinutesCorrectionsAndMembershipApproval < ActiveRecord::Migration[8.1]
  PERMISSION_CAPABILITIES = %w[
    manage_settings
    manage_people
    manage_meeting_bodies
    manage_agendas
    manage_minutes
    approve_minutes
    attest_minutes
    record_minutes_approval
    view_internal_records
  ].freeze

  POSITION_CAPABILITIES = (PERMISSION_CAPABILITIES - [ "manage_settings" ]).freeze

  def up
    remove_check_constraint :permission_grants, name: "permission_grants_capability_check"
    remove_check_constraint :position_capability_grants, name: "position_capability_grants_capability_check"

    execute <<~SQL.squish
      UPDATE permission_grants
      SET capability = 'record_minutes_approval', updated_at = CURRENT_TIMESTAMP
      WHERE capability = 'record_acceptance_motions'
    SQL
    execute <<~SQL.squish
      UPDATE position_capability_grants
      SET capability = 'record_minutes_approval', updated_at = CURRENT_TIMESTAMP
      WHERE capability = 'record_acceptance_motions'
    SQL

    add_capability_constraints
    grant_membership_approval_capability

    add_column :official_action_confirmations, :action_payload, :jsonb, null: false, default: {}
    replace_check_constraint :official_action_confirmations,
      name: "official_action_confirmations_action_check",
      expression: "action IN ('approve', 'attest', 'reopen', 'record_membership_approval')"

    replace_check_constraint :minutes_lifecycle_events,
      name: "minutes_lifecycle_events_type_check",
      expression: "event_type IN ('approved', 'attested', 'reopened', 'membership_approved')"

    if select_value("SELECT COUNT(*) FROM meeting_minutes WHERE status = 'accepted'").to_i.positive?
      raise ActiveRecord::IrreversibleMigration,
        "Legacy accepted minutes need an explicit membership-approval record before migration."
    end
    replace_check_constraint :meeting_minutes,
      name: "meeting_minutes_status_check",
      expression: "status IN ('draft', 'approved', 'attested', 'membership_approved')"

    create_table :minutes_membership_approvals do |t|
      t.references :meeting_minutes, null: false, foreign_key: true, index: { unique: true }
      t.references :minutes_revision, null: false, foreign_key: true, index: { unique: true }
      t.references :approving_meeting, null: false, foreign_key: { to_table: :meetings }
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.references :official_action_confirmation, null: false, foreign_key: true, index: { unique: true }
      t.string :disposition, null: false
      t.text :factual_note
      t.string :recorder_name, null: false
      t.string :recorder_office, null: false
      t.datetime :recorded_at, null: false
      t.timestamps
    end
    add_check_constraint :minutes_membership_approvals,
      "disposition IN ('approved_as_presented', 'approved_as_corrected', 'approved_by_motion', 'other')",
      name: "minutes_membership_approvals_disposition_check"

    execute <<~SQL
      CREATE TRIGGER minutes_membership_approvals_append_only
      BEFORE UPDATE OR DELETE ON minutes_membership_approvals
      FOR EACH ROW EXECUTE FUNCTION prevent_minutes_official_record_mutation();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Rolling this migration back could erase official membership-approval history."
  end

  private

  def replace_check_constraint(table, name:, expression:)
    remove_check_constraint table, name: name
    add_check_constraint table, expression, name: name
  end

  def add_capability_constraints
    add_check_constraint :permission_grants,
      "capability IN (#{PERMISSION_CAPABILITIES.map { |value| connection.quote(value) }.join(', ')})",
      name: "permission_grants_capability_check"
    add_check_constraint :position_capability_grants,
      "capability IN (#{POSITION_CAPABILITIES.map { |value| connection.quote(value) }.join(', ')})",
      name: "position_capability_grants_capability_check"
  end

  def grant_membership_approval_capability
    execute <<~SQL.squish
      INSERT INTO position_capability_grants
        (position_title_id, capability, created_at, updated_at)
      SELECT position_titles.id, 'record_minutes_approval', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM position_titles
      INNER JOIN organizations ON organizations.id = position_titles.organization_id
      WHERE organizations.unit_type = 'american_legion_post'
        AND position_titles.name IN ('Commander', 'Adjutant')
      ON CONFLICT (position_title_id, capability) DO NOTHING
    SQL
  end
end
