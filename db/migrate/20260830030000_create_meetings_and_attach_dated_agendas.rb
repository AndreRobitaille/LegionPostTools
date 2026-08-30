class CreateMeetingsAndAttachDatedAgendas < ActiveRecord::Migration[8.1]
  class LegacyOrganization < ActiveRecord::Base
    self.table_name = "organizations"
  end

  class LegacyMeetingBody < ActiveRecord::Base
    self.table_name = "meeting_bodies"
  end

  class LegacyDatedAgenda < ActiveRecord::Base
    self.table_name = "dated_agendas"
  end

  class BackfilledMeeting < ActiveRecord::Base
    self.table_name = "meetings"
  end

  def up
    create_table :meetings do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :meeting_body, null: false, foreign_key: true
      t.references :meeting_type, null: true, foreign_key: true
      t.datetime :starts_at, null: false
      t.string :title, null: false
      t.string :location_name, null: false
      t.text :location_address
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :meetings, %i[organization_id starts_at]

    add_reference :dated_agendas, :meeting, foreign_key: true, index: { unique: true }
    add_column :dated_agendas, :location_name, :string
    add_column :dated_agendas, :location_address, :text

    backfill_meetings_and_locations

    change_column_null :dated_agendas, :meeting_id, false
    change_column_null :dated_agendas, :location_name, false
  end

  def down
    remove_reference :dated_agendas, :meeting, foreign_key: true, index: true
    remove_column :dated_agendas, :location_name
    remove_column :dated_agendas, :location_address
    drop_table :meetings
  end

  private

  def backfill_meetings_and_locations
    LegacyDatedAgenda.reset_column_information
    BackfilledMeeting.reset_column_information

    organizations = LegacyOrganization.all.index_by(&:id)
    meeting_bodies = LegacyMeetingBody.all.index_by(&:id)

    say_with_time "Creating one Meeting for every dated agenda" do
      LegacyDatedAgenda.find_each do |agenda|
        organization = organizations.fetch(agenda.organization_id)
        meeting_body = meeting_bodies.fetch(agenda.meeting_body_id)
        location_name = meeting_body.default_location_name.presence ||
          organization.default_location_name.presence ||
          "Location not recorded"
        location_address = meeting_body.default_location_address.presence ||
          organization.default_location_address.presence

        meeting = BackfilledMeeting.create!(
          organization_id: agenda.organization_id,
          meeting_body_id: agenda.meeting_body_id,
          meeting_type_id: agenda.meeting_type_id,
          starts_at: agenda.starts_at,
          title: agenda.title,
          location_name: location_name,
          location_address: location_address,
          created_at: agenda.created_at,
          updated_at: agenda.updated_at
        )

        # This adds occurrence/document ownership and snapshots the venue. It
        # deliberately preserves the agenda's timestamps and lock version.
        agenda.update_columns(
          meeting_id: meeting.id,
          location_name: location_name,
          location_address: location_address
        )
      end
    end
  end
end
