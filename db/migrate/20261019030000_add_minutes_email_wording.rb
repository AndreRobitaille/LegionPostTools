class AddMinutesEmailWording < ActiveRecord::Migration[8.1]
  def change
    add_column :minutes_distribution_settings, :email_subject_template, :text
    add_column :minutes_distribution_settings, :email_cover_note_template, :text
    add_column :minutes_distribution_settings, :lock_version, :integer, null: false, default: 0
    add_column :minutes_distributions, :email_wording, :jsonb, null: false, default: {}
  end
end
