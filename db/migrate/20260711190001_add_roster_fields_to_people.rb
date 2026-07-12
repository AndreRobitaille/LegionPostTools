class AddRosterFieldsToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :roster_name, :string
    add_column :people, :roster_post, :string
    add_column :people, :roster_membership_type, :string
    add_column :people, :roster_address, :text
    add_column :people, :roster_undeliverable, :boolean, null: false, default: false
    add_column :people, :roster_email_address, :string
    add_column :people, :roster_phone_number, :string
    add_column :people, :roster_branch, :string
    add_column :people, :roster_war_era, :string
    add_column :people, :roster_continuous_years, :integer
    add_column :people, :roster_paid_through_year, :integer
    add_column :people, :roster_member_status, :string
    add_column :people, :roster_imported_at, :datetime

    add_index :people, :roster_email_address
    add_index :people, :roster_member_status
    add_index :people, :roster_paid_through_year

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE people
          SET member_number = NULL
          WHERE member_number IS NOT NULL AND btrim(member_number) = ''
        SQL
      end
    end

    remove_index :people, :member_number if index_exists?(:people, :member_number)
    add_index :people, :member_number, unique: true, where: "member_number IS NOT NULL"
  end
end
