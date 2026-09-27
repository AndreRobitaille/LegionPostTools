class CreateWebsitePublishing < ActiveRecord::Migration[8.1]
  EXISTING_CAPABILITIES = %w[manage_settings manage_people manage_meeting_bodies manage_agendas manage_minutes approve_minutes attest_minutes record_minutes_approval view_internal_records].freeze

  def change
    reversible do |dir|
      dir.up { capability_constraints(EXISTING_CAPABILITIES + [ "publish_public_content" ]) }
      dir.down { capability_constraints(EXISTING_CAPABILITIES) }
    end
    add_column :calendar_events, :website_designation, :string, null: false, default: "unreviewed"
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE calendar_events SET website_designation = 'internal'
          WHERE calendar_category IN ('member_meeting', 'officer_meeting', 'planning_meeting', 'honor_guard')
        SQL
      end
    end

    create_table :website_publications do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :calendar_event, foreign_key: true, index: { unique: true }
      t.bigint :original_calendar_event_id
      t.string :kind, null: false
      t.string :public_id, null: false, index: { unique: true }
      t.jsonb :draft, null: false, default: {}
      t.jsonb :snapshot, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.boolean :consent, null: false, default: false
      t.text :consent_note
      t.text :eligibility_reason
      t.integer :eligibility_source_version
      t.integer :published_source_version
      t.integer :featured_position
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :website_publications, [ :organization_id, :featured_position ], unique: true, where: "featured_position IS NOT NULL", name: "website_featured_positions"
    add_check_constraint :website_publications, "featured_position IS NULL OR featured_position BETWEEN 1 AND 3", name: "website_featured_limit"

    create_table :website_portraits do |t|
      t.references :website_publication, null: false, foreign_key: true
      t.string :revision, null: false, index: { unique: true }
      t.binary :small, null: false
      t.binary :large, null: false
      t.timestamps
    end

    create_table :website_publication_events do |t|
      t.references :website_publication, null: false, foreign_key: true
      t.bigint :actor_id
      t.string :action, null: false
      t.integer :version, null: false
      t.jsonb :details, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end

  private

  def capability_constraints(capabilities)
    { permission_grants: capabilities, position_capability_grants: capabilities - [ "manage_settings" ] }.each do |table, values|
      name = "#{table}_capability_check"
      remove_check_constraint table, name: name
      add_check_constraint table, "capability IN (#{values.map { |value| connection.quote(value) }.join(', ')})", name: name
    end
  end
end
