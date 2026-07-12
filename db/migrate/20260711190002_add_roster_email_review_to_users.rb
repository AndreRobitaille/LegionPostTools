class AddRosterEmailReviewToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :roster_email_reviewed_address, :string
    add_column :users, :roster_email_review_decision, :string
    add_column :users, :roster_email_reviewed_at, :datetime
  end
end
