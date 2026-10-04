class AllowMinutesAttestationWithoutCommanderEndorsement < ActiveRecord::Migration[8.1]
  def up
    %i[approved_by_id approver_name approver_office approved_at].each do |column|
      change_column_null :minutes_revisions, column, true
    end
    add_check_constraint :minutes_revisions,
      "(approved_by_id IS NULL AND approver_name IS NULL AND approver_office IS NULL AND approved_at IS NULL) OR " \
      "(approved_by_id IS NOT NULL AND approver_name IS NOT NULL AND approver_office IS NOT NULL AND approved_at IS NOT NULL)",
      name: "minutes_revisions_commander_endorsement_check"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Adjutant-attested revisions must not acquire invented Commander endorsements."
  end
end
