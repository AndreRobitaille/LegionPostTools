class AddPrintContactDetailsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :mailing_address, :text
    add_column :organizations, :public_email, :string
  end
end
