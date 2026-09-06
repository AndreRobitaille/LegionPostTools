class AddCalendarCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :calendar_events, :calendar_category, :string
    add_column :meetings, :calendar_category, :string
  end
end
