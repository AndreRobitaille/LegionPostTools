# Run only through bin/publisher-demo. The dedicated scratch database contains
# synthetic content and is intentionally independent of development/member data.
require "stringio"
raise "Use the isolated publisher demo database" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "legion_post_tools_publisher_demo_test"

organization = Organization.first
if organization
  raise "This database is not the publisher demo" unless organization.name == "Synthetic publisher demonstration"
else
  organization = Organization.create!(name: "Synthetic publisher demonstration", unit_type: "american_legion_post", timezone: "America/Chicago")
  person = Person.create!(first_name: "Synthetic", last_name: "Editor")
  user = User.create!(person: person, email_address: "publisher-demo@example.test")
  %w[publish_public_content manage_settings].each { |capability| user.permission_grants.create!(capability: capability) }
  Installation.singleton.update!(setup_completed_at: Time.current)
  publication = WebsitePublication.create_draft!(organization: organization, actor: user)
  # A plain color test card, not a real or invented member portrait.
  bytes = Vips::Image.black(640, 800).new_from_image([ 65, 92, 121 ]).write_to_buffer(".png")
  publication.edit_draft!(actor: user, version: publication.lock_version, attributes: {
    display_name: "Avery (fictional)", introduction: "A synthetic introduction for public-site integration.",
    story: "This is a test story. No real member is represented and no real event is advertised.",
    conversation_starter: "Ask about this demonstration.", portrait_alt: "Blue test card; no person pictured"
  }, portrait: StringIO.new(bytes))
  publication.confirm_consent!(actor: user, version: publication.lock_version, note: "Synthetic fixture; no personal data")
  publication.publish!(actor: user, version: publication.lock_version)
  WebsitePublication.feature!(organization: organization, actor: user, ids: [ publication.public_id ], versions: { publication.id.to_s => publication.lock_version.to_s })
  zone = organization.calendar_time_zone
  [
    { title: "Synthetic public gathering", starts_at: zone.local(2026, 10, 3, 18), ends_at: zone.local(2026, 10, 3, 20), all_day: false },
    { title: "Synthetic all-day activity", starts_at: zone.local(2026, 10, 10), ends_at: zone.local(2026, 10, 11).end_of_day, all_day: true, cancelled: true }
  ].each do |fields|
    source = organization.calendar_events.create!(**fields, description: "Synthetic event for integration testing only.", location: "Example hall (not a real event)", visibility: "public", created_by: user, updated_by: user)
    event = WebsitePublication.create_draft!(organization: organization, actor: user, calendar_event: source)
    event.approve_eligibility!(actor: user, version: event.lock_version, source_version: source.lock_version, reason: "Synthetic fixture is public test data")
    event.publish!(actor: user, version: event.lock_version, source_version: source.reload.lock_version)
  end
end
puts "Synthetic API: #{ENV.fetch('PUBLIC_PUBLISHER_ORIGIN')}/public/v1/featured_members"
puts "Events: #{ENV.fetch('PUBLIC_PUBLISHER_ORIGIN')}/public/v1/events?from=2026-10-01&to=2026-11-01"
