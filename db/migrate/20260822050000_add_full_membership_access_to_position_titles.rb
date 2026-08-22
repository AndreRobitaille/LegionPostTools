class AddFullMembershipAccessToPositionTitles < ActiveRecord::Migration[8.1]
  MEMBERSHIP_LEADERSHIP_TITLES = [ "Commander", "1st Vice Commander", "Adjutant" ].freeze

  def up
    add_column :position_titles, :grants_full_membership_access, :boolean, null: false, default: false

    quoted_titles = MEMBERSHIP_LEADERSHIP_TITLES.map { |title| connection.quote(title) }.join(", ")
    execute <<~SQL.squish
      UPDATE position_titles
      SET grants_full_membership_access = TRUE
      WHERE name IN (#{quoted_titles})
    SQL
  end

  def down
    remove_column :position_titles, :grants_full_membership_access
  end
end
