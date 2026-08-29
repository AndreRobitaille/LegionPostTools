class UpgradeSeededRollCallBehavior < ActiveRecord::Migration[8.1]
  class CatalogEntry < ActiveRecord::Base
    self.table_name = "agenda_item_catalog_entries"
  end

  SOURCE_KEY = "regular_meeting.roll_call_quorum"
  SOURCE_LABEL = "Officer's Guide regular meeting seed"

  def up
    CatalogEntry
      .where(source_key: SOURCE_KEY, source_label: SOURCE_LABEL, behavior_type: "business_item")
      .update_all(behavior_type: "roll_call", updated_at: Time.current)
  end

  def down
    CatalogEntry
      .where(source_key: SOURCE_KEY, source_label: SOURCE_LABEL, behavior_type: "roll_call")
      .update_all(behavior_type: "business_item", updated_at: Time.current)
  end
end
