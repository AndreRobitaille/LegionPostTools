# Synthetic integration fixture. Refuses development, production, or a populated DB.
raise "Isolated synthetic database required" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "legion_buddy_mobile_test"
raise "Database must be empty; this script never resets data" if User.exists? || Organization.exists?
organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
Installation.singleton.update!(setup_completed_at: Time.current)
caller = User.create!(person: Person.create!(first_name: "Jamie", last_name: "Caller"), email_address: "jamie@example.test")
officer = User.create!(person: Person.create!(first_name: "Riley", last_name: "Reviewer"), email_address: "riley@example.test")
[ caller, officer ].each do |user|
  %w[use_mobile_buddy_checks export_buddy_contacts].each { |capability| user.permission_grants.create!(capability:) }
end
title = organization.position_titles.create!(name: "Membership reviewer", display_order: 1, grants_full_membership_access: true)
PositionAssignment.create!(person: officer.person, position_title: title, starts_on: Date.current - 30)
client = Doorkeeper::Application.create!(name: "Synthetic iPhone Buddy Checks",
  redirect_uri: ENV.fetch("MOBILE_BUDDY_CHECK_REDIRECT_URI", "org.example.buddy:/callback"), scopes: "buddy_check", confidential: false)
people = %w[Alex Blair Casey Dana Evan Frankie Morgan Harper].each_with_index.to_h do |name, index|
  [ name, Person.create!(first_name: name, last_name: "Example", member_number: (index + 1).to_s.rjust(12, "0"),
    roster_member_status: "Active", roster_paid_through_year: Date.current.year,
    roster_phone_number: "+1-202-555-01#{index.to_s.rjust(2, '0')}", roster_email_address: "#{name.downcase}@example.test",
    roster_address: "Synthetic flat source; components unknown", roster_imported_at: Time.current) ]
end
access = BuddyChecks::Access.new(user: caller, organization:)
operations = BuddyChecks::Operations.new(access)
{ "Alex" => 100.days.ago, "Casey" => 1.day.ago }.each do |name, instant|
  operations.record(operation_id: SecureRandom.uuid, person_id: people.fetch(name).id,
    facts: { channel: "phone", outcome: "reached", occurred_at: instant.iso8601(6), entry_zone: "America/Chicago" })
end
organization.membership_contacts.create!(person: people.fetch("Dana"), recorded_by: officer, membership_year: Date.current.year,
  purpose: "buddy_check", channel: "phone", outcome: "do_not_contact", occurred_on: Organization.current_local_date,
  submission_key: SecureRandom.uuid, notes: "Synthetic contact pause; private officer note")
people.fetch("Evan").update!(roster_member_status: "Expired")
drive = organization.membership_drives.create!(title: "Synthetic Buddy Checks", purpose: "buddy_check", membership_year: Date.current.year,
  starts_on: Date.current - 1, ends_on: Date.current + 14, created_by: officer)
drive.assignments.create!(person: people.fetch("Evan"), assigned_to: caller, assigned_by: officer, expires_on: drive.ends_on)
operations.schedule(operation_id: SecureRandom.uuid, person_id: people.fetch("Frankie").id, due_at: 2.days.from_now.iso8601, entry_zone: "America/Chicago")
body = organization.meeting_bodies.create!(name: "Membership Meeting", slug: "membership")
[ 40, 10 ].each do |days|
  meeting = organization.meetings.create!(meeting_body: body, title: "Synthetic membership meeting", starts_at: days.days.ago, location_name: "Example Hall")
  entries = Person.roster_backed.directory_visible.pluck(:id).to_h { |id| [ id.to_s, id == people.fetch("Morgan").id ? "absent" : "present" ] }
  BuddyAttendanceRegister.record!(meeting:, user: officer, expected_revision: 0, entries:, complete: true, coverage_note: "Synthetic complete general-member register; no real attendance.")
end
issuer = ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER", "http://localhost:3107")
fixture = { issuer:, client_id: client.uid, callback: client.redirect_uri, caller_id: caller.id, officer_id: officer.id,
  people: people.transform_values(&:id),
  caller_sign_in: "#{issuer}/session/magic_link?token=#{MagicLink.create_for!(caller).token}",
  officer_sign_in: "#{issuer}/session/magic_link?token=#{MagicLink.create_for!(officer).token}" }
path = ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE", "/tmp/legion-buddy-mobile-fixture.json")
File.write(path, JSON.pretty_generate(fixture), perm: 0o600)
puts "Synthetic fixture ready. Public client configuration and short-lived synthetic sign-in links are in #{path}; do not commit this file. No email was sent."
