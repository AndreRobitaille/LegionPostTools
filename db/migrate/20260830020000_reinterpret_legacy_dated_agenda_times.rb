class ReinterpretLegacyDatedAgendaTimes < ActiveRecord::Migration[8.1]
  class LegacyOrganization < ActiveRecord::Base
    self.table_name = "organizations"
  end

  class LegacyDatedAgenda < ActiveRecord::Base
    self.table_name = "dated_agendas"

    belongs_to :legacy_organization,
      class_name: "ReinterpretLegacyDatedAgendaTimes::LegacyOrganization",
      foreign_key: :organization_id
  end

  def up
    reinterpret_times(from: :utc_wall, to: :organization_zone)
  end

  def down
    reinterpret_times(from: :organization_zone, to: :utc_wall)
  end

  private

  def reinterpret_times(from:, to:)
    say_with_time "Reinterpreting legacy dated agenda times from #{from} to #{to}" do
      LegacyDatedAgenda.includes(:legacy_organization).find_each do |agenda|
        zone = organization_zone!(agenda.legacy_organization)
        corrected_time = if to == :organization_zone
          utc_components_in_zone(agenda.starts_at, zone)
        else
          zoned_components_in_utc(agenda.starts_at, zone)
        end

        # This is a storage correction, not a document edit. Preserve the agenda's
        # optimistic-lock and historical update metadata.
        agenda.update_columns(starts_at: corrected_time)
      end
    end
  end

  def organization_zone!(organization)
    ActiveSupport::TimeZone[organization.timezone] ||
      raise(ArgumentError, "Organization #{organization.id} has invalid timezone #{organization.timezone.inspect}")
  end

  def utc_components_in_zone(time, zone)
    legacy_wall_time = time.utc
    zone.local(
      legacy_wall_time.year,
      legacy_wall_time.month,
      legacy_wall_time.day,
      legacy_wall_time.hour,
      legacy_wall_time.min,
      legacy_wall_time.sec + legacy_wall_time.subsec
    )
  end

  def zoned_components_in_utc(time, zone)
    local_wall_time = time.in_time_zone(zone)
    Time.utc(
      local_wall_time.year,
      local_wall_time.month,
      local_wall_time.day,
      local_wall_time.hour,
      local_wall_time.min,
      local_wall_time.sec + local_wall_time.subsec
    )
  end
end
