# Read-only; run inside the production container through bin/release's shared transport.
# Prints configuration and aggregate fingerprints, never member rows or credentials.
email = ENV.fetch("BUDDY_CHECK_ACTIVATE_EMAIL")
connection = ActiveRecord::Base.connection
organization = Organization.first!
user = User.find_by!(email_address: email)
tables = %w[people roster_imports membership_assignments membership_drives membership_contacts
  membership_dues_records membership_summaries meeting_minutes minutes_revisions minutes_attestations
  minutes_membership_approvals minutes_lifecycle_events]
added_columns = %w[buddy_address_source_version occurred_at entry_zone revision supersedes_contact_id logical_contact_id]
exclusions = added_columns.map { |column| connection.quote(column) }.join(",")
fingerprints = tables.to_h do |table|
  quoted = connection.quote_table_name(table)
  row = connection.select_one("SELECT count(*) AS count, md5(coalesce(string_agg((to_jsonb(t) - ARRAY[#{exclusions}]::text[])::text, E'\\n' ORDER BY id), '')) AS fingerprint FROM #{quoted} t")
  [ table, row ]
end
versions = connection.select_values("SELECT version FROM schema_migrations ORDER BY version")
client = if connection.table_exists?(:oauth_applications)
  Doorkeeper::Application.find_by(uid: ENV["MOBILE_BUDDY_CHECK_CLIENT_ID"])
end
report = {
  installation: { id: organization.id, name: organization.name, timezone: organization.calendar_time_zone.tzinfo.identifier },
  user: { id: user.id, enabled: user.disabled_at.nil?, full_membership_access: user.full_membership_access?,
    pilot_access: user.can?("use_mobile_buddy_checks"), contacts_export: user.can?("export_buddy_contacts") },
  pilot_grants: { manual_user_ids: PermissionGrant.where(capability: "use_mobile_buddy_checks").order(:user_id).pluck(:user_id),
    role_grants: PositionCapabilityGrant.where(capability: "use_mobile_buddy_checks").count },
  settings: ENV.to_h.slice("APP_HOST", "APP_TIME_ZONE", "MAIL_PROVIDER", "MAIL_FROM",
    "MOBILE_BUDDY_CHECK_ENABLED", "MOBILE_BUDDY_CHECK_ISSUER", "MOBILE_BUDDY_CHECK_CLIENT_ID",
    "MOBILE_BUDDY_CHECK_REDIRECT_URI", "MOBILE_CONTACT_EXPORT_ENABLED", "MOBILE_CONTACT_COMPANY"),
  mail: { api_key_configured: ENV["LOOPS_API_KEY"].present?, template_configured: ENV["LOOPS_MAGIC_LINK_TEMPLATE_ID"].present? },
  mobile_migrations: versions & %w[20261011210000 20261011211000 20261012120000],
  client: client && { id: client.uid, redirect_uri: client.redirect_uri, scopes: client.scopes.to_s,
    public_client: !client.confidential?, secret_absent: client.secret.nil? },
  fingerprints:
}
if ENV["BUDDY_CHECK_REQUIRE_READY"] == "true"
  raise "Mobile features disabled" unless ENV["MOBILE_BUDDY_CHECK_ENABLED"] == "true" && ENV["MOBILE_CONTACT_EXPORT_ENABLED"] == "true"
  raise "Mobile migrations missing" unless report[:mobile_migrations].size == 3
  raise "Mobile client unavailable or incompatible" unless client && BuddyChecks::Configuration.client?(client) &&
    client.redirect_uri == ENV.fetch("MOBILE_BUDDY_CHECK_REDIRECT_URI") && client.secret.nil?
  raise "First mobile user's access unavailable" unless user.disabled_at.nil? &&
    user.can?("use_mobile_buddy_checks") && user.can?("export_buddy_contacts")
  raise "Pilot access is not limited to the first user" unless report[:pilot_grants] == { manual_user_ids: [ user.id ], role_grants: 0 }
end
puts "BUDDY_CHECK_READINESS #{report.to_json}"
