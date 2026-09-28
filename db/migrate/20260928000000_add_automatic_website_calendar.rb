class AddAutomaticWebsiteCalendar < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :website_calendar_enabled, :boolean, default: false, null: false
    add_column :organizations, :website_calendar_types, :jsonb, default: %w[member_meeting public_event], null: false
    add_column :organizations, :website_calendar_version, :integer, default: 0, null: false

    %i[calendar_events meetings].each do |table|
      add_column table, :website_listing, :string, default: "default", null: false
      add_column table, :website_public_id, :string, default: -> { "replace(gen_random_uuid()::text, '-', '')" }, null: false
      add_column table, :website_title, :string
      add_column table, :website_description, :text
      add_column table, :attendance, :string, default: "members", null: false
      add_index table, :website_public_id, unique: true
    end
    add_column :meetings, :cancelled, :boolean, default: false, null: false

    reversible do |dir|
      dir.up do
        execute "UPDATE calendar_events SET attendance = visibility"
        execute <<~SQL
          UPDATE calendar_events AS event
          SET website_public_id = publication.public_id,
              website_listing = CASE publication.status WHEN 'published' THEN 'show' WHEN 'withdrawn' THEN 'hide' ELSE 'default' END,
              website_title = publication.snapshot->>'title',
              website_description = publication.snapshot->>'description'
          FROM website_publications AS publication
          WHERE publication.calendar_event_id = event.id AND publication.kind = 'event'
        SQL
      end
    end

    create_table :website_calendar_changes do |t|
      t.references :organization, null: false, foreign_key: true
      t.bigint :actor_id
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.string :action, null: false
      t.jsonb :details, default: {}, null: false
      t.datetime :created_at, null: false
    end
  end
end
