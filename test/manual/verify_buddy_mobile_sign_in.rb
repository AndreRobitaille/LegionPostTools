require_relative "buddy_mobile_probe"
raise "Synthetic integration database required" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "legion_buddy_mobile_test"
raise "Synthetic installation required" unless Organization.sole.name == "Example American Legion Post"
ActiveRecord::Base.connection.disable_query_cache!
fixture = JSON.parse(File.read(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE")))
before = [ MembershipContact.count, BuddyOperation.count, BuddyFollowUp.count ]
%w[caller officer].each do |role|
  user = User.find(fixture.fetch("#{role}_id"))
  probe = BuddyMobileProbe.new
  probe.sign_in(user, use_code: true)
  probe.assert(probe.api("get", "/session").dig("user", "id") == user.id, "Signed in as the wrong synthetic account")
  revoked = probe.request("post", "/oauth/revoke", form: { client_id: ENV.fetch("MOBILE_BUDDY_CHECK_CLIENT_ID"), token: probe.token })
  probe.assert(revoked.code == "200", "Probe token cleanup failed")
end
raise "Sign-in changed Buddy Check work" unless before == [ MembershipContact.count, BuddyOperation.count, BuddyFollowUp.count ]
puts "PASS: actual HTTPS email form, private local delivery, browser-bound code, consent and PKCE for both synthetic accounts; no contact changes."
