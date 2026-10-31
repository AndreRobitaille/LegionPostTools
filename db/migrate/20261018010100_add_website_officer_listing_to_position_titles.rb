class AddWebsiteOfficerListingToPositionTitles < ActiveRecord::Migration[8.1]
  OFFICES = [
    "Commander", "1st Vice Commander", "2nd Vice Commander", "Adjutant", "Finance Officer",
    "Chaplain", "Sergeant-at-Arms", "Historian", "Service Officer", "Judge Advocate", "Assistant Chaplain"
  ].freeze

  def up
    add_column :position_titles, :website_officer_listing, :boolean, null: false, default: false
    execute <<~SQL
      UPDATE position_titles SET website_officer_listing = TRUE
      WHERE name IN (#{OFFICES.map { |name| connection.quote(name) }.join(', ')})
    SQL
  end

  def down
    remove_column :position_titles, :website_officer_listing
  end
end
