class AddTextVerbosityToMinutesDraftRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :minutes_draft_runs, :text_verbosity, :string, null: false, default: "low"
    change_column_default :minutes_draft_runs, :text_verbosity, from: "low", to: nil
  end
end
