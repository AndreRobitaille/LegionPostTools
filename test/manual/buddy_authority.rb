require "json"
require "uri"

rehearsal = ARGV.first == "--rehearsal"
ARGV.shift if rehearsal
database = rehearsal ? "legion_buddy_authority_verify_test" : "legion_buddy_authority_test"
directory = rehearsal ? "/tmp/legion-buddy-authority-verify" : "/tmp/legion-buddy-authority"
port = rehearsal ? 3445 : 3444
path = File.join(directory, "environment.json")
raise "Private environment file required" unless File.stat(path).uid == Process.uid && (File.stat(path).mode & 0o077).zero?
configuration = JSON.parse(File.read(path))
raise "Wrong disposable database" unless configuration.fetch("DATABASE_URL") == "postgresql:///#{database}"
raise "Test integration mode required" unless configuration.fetch("RAILS_ENV") == "test" && configuration.fetch("BUDDY_MOBILE_INTEGRATION") == "true"
raise "Wrong dedicated HTTPS port" unless URI(configuration.fetch("MOBILE_BUDDY_CHECK_ISSUER")).then { |uri| uri.scheme == "https" && uri.port == port }
raise "Wrong fixture directory" unless configuration.fetch("BUDDY_MOBILE_FIXTURE_FILE") == File.join(directory, "fixture.json")
File.umask(0o077)
ENV.update(configuration)
ENV.delete("SOLID_QUEUE_IN_PUMA")
Dir.chdir(File.expand_path("../..", __dir__))

case command = ARGV.shift
when "server"
  exec "bundle", "exec", "puma", "-C", "test/manual/buddy_authority_puma.rb"
when "setup", "status", "advance", "reconcile"
  exec "bin/rails", "runner", "test/manual/buddy_authority_control.rb", command, *ARGV
when "reminder"
  raise "Reminder acceptance uses only the live synthetic authority fixture" if rehearsal
  exec "bin/rails", "runner", "test/manual/buddy_reminder_control.rb", *ARGV
when "verify"
  raise "Verification may only change the rehearsal database" unless rehearsal
  exec "bin/rails", "runner", "test/manual/verify_buddy_authority.rb"
when "verify-initial"
  exec "bin/rails", "runner", "test/manual/verify_buddy_authority_initial.rb"
else
  abort "Usage: ruby test/manual/buddy_authority.rb [--rehearsal] server|setup|status|advance ACTION CHECKPOINT|reconcile USER_ID PERSON_ID OPERATION_UUID|verify|verify-initial|reminder setup|status|advance ACTION CHECKPOINT"
end
