require_relative "buddy_authority_fixture"

case ARGV.shift
when "setup"
  fixture = BuddyAuthorityFixture.setup!
  directory = File.dirname(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE"))
  path = File.join(directory, "environment.json")
  configuration = JSON.parse(File.read(path)).merge("MOBILE_BUDDY_CHECK_CLIENT_ID" => fixture.fetch(:client_id))
  File.write(path, JSON.pretty_generate(configuration), perm: 0o600)
  puts JSON.pretty_generate(fixture)
when "status"
  puts JSON.pretty_generate(BuddyAuthorityFixture.new.status)
when "advance"
  action, checkpoint = ARGV
  puts JSON.pretty_generate(BuddyAuthorityFixture.new.advance!(action, checkpoint:))
when "reconcile"
  user_id, person_id, operation_id = ARGV
  puts JSON.pretty_generate(BuddyAuthorityFixture.new.reconcile(user_id: Integer(user_id), person_id: Integer(person_id), operation_id:))
else
  abort "Use the guarded buddy_authority.rb entry point."
end
