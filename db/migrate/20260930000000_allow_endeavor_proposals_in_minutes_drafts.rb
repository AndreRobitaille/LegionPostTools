class AllowEndeavorProposalsInMinutesDrafts < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :minutes_draft_suggestions,
      "kind IN ('item_summary', 'outcome', 'attendance', 'additional_item')",
      name: "minutes_draft_suggestions_kind_check"
    add_check_constraint :minutes_draft_suggestions,
      "kind IN ('item_summary', 'outcome', 'attendance', 'additional_item', 'endeavor_proposal')",
      name: "minutes_draft_suggestions_kind_check"
  end
end
