require "json"

root = File.expand_path("../..", __dir__)
path = ENV.fetch("BUDDY_MOBILE_ENV_FILE", "/tmp/legion-buddy-mobile/environment.json")
raise "Private environment file required" unless (File.stat(path).mode & 0o077).zero? && File.stat(path).uid == Process.uid
configuration = JSON.parse(File.read(path))
raise "Synthetic database required" unless configuration.fetch("DATABASE_URL") == "postgresql:///legion_buddy_mobile_test"
raise "Test environment required" unless configuration.fetch("RAILS_ENV") == "test" && configuration.fetch("BUDDY_MOBILE_INTEGRATION") == "true"
File.umask(0o077)
ENV.update(configuration)
ENV.delete("SOLID_QUEUE_IN_PUMA")
Dir.chdir(root)

case ARGV.shift
when "server"
  exec "bundle", "exec", "puma", "-C", "test/manual/buddy_mobile_puma.rb"
when "sign-in"
  exec "bin/rails", "runner", "test/manual/refresh_buddy_mobile_sign_in.rb"
when "setup"
  exec "bin/rails", "runner", "test/manual/setup_buddy_mobile.rb"
when "verify"
  exec "bin/rails", "runner", "test/manual/verify_buddy_mobile.rb"
when "verify-sign-in"
  exec "bin/rails", "runner", "test/manual/verify_buddy_mobile_sign_in.rb"
else
  abort "Usage: ruby test/manual/buddy_mobile.rb server|sign-in|setup|verify|verify-sign-in"
end
