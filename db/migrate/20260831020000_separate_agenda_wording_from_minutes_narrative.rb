class SeparateAgendaWordingFromMinutesNarrative < ActiveRecord::Migration[8.1]
  def up
    MinutesAgendaWordingBackfill.call
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Agenda wording and recorded minutes must remain separate"
  end
end
