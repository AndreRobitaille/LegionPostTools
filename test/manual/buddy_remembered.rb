require "json"

directory = "/tmp/legion-buddy-remembered"
path = File.join(directory, "environment.json")
raise "Private environment file required" unless File.stat(path).uid == Process.uid && (File.stat(path).mode & 0o077).zero?
configuration = JSON.parse(File.read(path))
expected = {
  "DATABASE_URL" => "postgresql:///legion_buddy_remembered_test", "RAILS_ENV" => "test",
  "BUDDY_MOBILE_INTEGRATION" => "true", "MOBILE_BUDDY_CHECK_ISSUER" => "https://192.168.37.41:3446",
  "BUDDY_MOBILE_FIXTURE_FILE" => File.join(directory, "fixture.json")
}
raise "Dedicated synthetic configuration required" unless configuration.slice(*expected.keys) == expected
File.umask(0o077)
ENV.update(configuration)
ENV.delete("SOLID_QUEUE_IN_PUMA")
Dir.chdir(File.expand_path("../..", __dir__))
case command = ARGV.shift
when "server"
  exec "bundle", "exec", "puma", "-C", "test/manual/buddy_remembered_puma.rb"
when "setup", "status", "advance"
  exec "bin/rails", "runner", "test/manual/buddy_remembered_control.rb", command, *ARGV
else
  abort "Usage: ruby test/manual/buddy_remembered.rb server|setup|status|advance ACTION CHECKPOINT"
end
