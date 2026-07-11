class AddLocalityToOrganizations < ActiveRecord::Migration[8.1]
  def change
    # The post's home city/state for identity (e.g. "Two Rivers, WI"), distinct
    # from default_location_name, which is the meeting venue.
    add_column :organizations, :locality, :string
  end
end
