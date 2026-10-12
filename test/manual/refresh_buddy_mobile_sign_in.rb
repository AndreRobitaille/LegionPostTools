raise "Synthetic integration database required" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "legion_buddy_mobile_test"
raise "Synthetic installation required" unless Organization.sole.name == "Example American Legion Post"
path = ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE", "/tmp/legion-buddy-mobile-fixture.json")
fixture = JSON.parse(File.read(path))
raise "Integration origin mismatch" unless fixture.fetch("issuer") == ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER")
{ "caller" => "jamie@example.test", "officer" => "riley@example.test" }.each do |role, email|
  user = User.find_by!(email_address: email)
  raise "Synthetic identity mismatch" unless fixture.fetch("#{role}_id") == user.id
  fixture["#{role}_sign_in"] = "#{fixture.fetch('issuer')}/session/magic_link?token=#{MagicLink.create_for!(user).token}"
end
fixture["sign_in_expires_at"] = MagicLink::TOKEN_TTL.from_now.iso8601
File.write(path, JSON.pretty_generate(fixture), perm: 0o600)
puts "Fresh synthetic sign-in links saved privately to #{path}. Valid for 15 minutes; no email sent."
