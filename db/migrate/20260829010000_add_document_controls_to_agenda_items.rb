class AddDocumentControlsToAgendaItems < ActiveRecord::Migration[8.1]
  def change
    %i[agenda_item_catalog_entries meeting_type_agenda_items dated_agenda_items].each do |table|
      change_table table, bulk: true do |t|
        t.boolean :show_wording_on_agenda, null: false, default: true
        t.boolean :show_wording_in_minutes, null: false, default: true
      end
    end
  end
end
