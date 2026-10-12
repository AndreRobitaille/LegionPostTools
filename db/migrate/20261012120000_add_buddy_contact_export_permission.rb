class AddBuddyContactExportPermission < ActiveRecord::Migration[8.1]
  EXISTING_CAPABILITIES = %w[manage_settings manage_people manage_meeting_bodies manage_agendas manage_minutes
    approve_minutes attest_minutes record_minutes_approval view_internal_records publish_public_content].freeze

  def up
    replace_capabilities(EXISTING_CAPABILITIES + %w[use_mobile_buddy_checks export_buddy_contacts])
  end

  def down
    # Retained grants require an explicit operator decision before rolling back.
    replace_capabilities(EXISTING_CAPABILITIES)
  end

  private

  def replace_capabilities(capabilities)
    { permission_grants: capabilities, position_capability_grants: capabilities - [ "manage_settings" ] }.each do |table, values|
      name = "#{table}_capability_check"
      remove_check_constraint(table, name:)
      add_check_constraint(table, "capability IN (#{values.map { |value| connection.quote(value) }.join(', ')})", name:)
    end
  end
end
