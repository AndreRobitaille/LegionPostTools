require_relative "buddy_authority_fixture"
require_relative "buddy_mobile_probe"

ActiveRecord::Base.connection.disable_query_cache!
control = BuddyAuthorityFixture.new
fixture = control.fixture
state = control.status
raise "Initial state required; do not reset" unless state[:contacts] == 2 && state[:receipts] == 2 && state[:registers].empty? &&
  !state[:paused] && state[:reviewer_authorized] && state[:assignments].size == 1 && state[:assignments].first["revoked_at"].nil?
models = [ Person, MembershipContact, BuddyOperation, MembershipAssignment, PositionAssignment, BuddyAddressReview,
  BuddyAttendanceRegister, BuddyFollowUp, BuddySnooze, Meeting, MeetingMinutes ]
before = models.to_h { |model| [ model, model.order(:id).map(&:attributes) ] }
caller = BuddyMobileProbe.new
reviewer = BuddyMobileProbe.new
caller.sign_in(User.find(fixture.fetch("caller_id")), use_code: true)
reviewer.sign_in(User.find(fixture.fetch("reviewer_id")), use_code: true)
checks = 0
check = ->(condition, message) { checks += 1; raise message unless condition }
people = fixture.fetch("people")
people.each do |key, id|
  card = caller.api("get", "/buddy-checks/people/#{id}")
  check.call(card.dig("eligibility", "eligible") && card["phone"].present?, "Initial #{key} card is not eligible")
end
hidden_export = caller.api("get", "/people/#{people.fetch('member')}/contact-export", status: 403)
check.call(hidden_export.dig("error", "code") == "export_not_permitted", "Assignment unexpectedly permitted export")
full_export = reviewer.api("get", "/people/#{people.fetch('export')}/contact-export")
check.call(full_export["address_coverage"] == "reviewed_components" && full_export["address_review_id"] == fixture.fetch("address_review_id"), "Reviewer address missing")
%w[coordination attendance].each do |key|
  query = { exclude_ids: Person.pluck(:id) - [ people.fetch(key) ] }.to_query
  suggestion = caller.api("get", "/buddy-checks/suggestion?#{query}")
  if key == "coordination"
    check.call(suggestion["reason"] == "recorded_contact_is_older" && suggestion.dig("person", "id") == people.fetch(key), "Coordination candidate missing")
  else
    check.call(suggestion["state"] == "insufficient_history", "Unknown attendance became absence")
  end
end
[ caller, reviewer ].each do |probe|
  check.call(probe.request("post", "/oauth/revoke", form: { client_id: fixture.fetch("client_id"), token: probe.token }).code == "200", "Probe token cleanup failed")
end
models.each { |model| check.call(before.fetch(model) == model.order(:id).map(&:attributes), "Initial #{model} rows changed") }
puts "PASS: #{checks} initial-state HTTPS assertions; normal email/code/consent/PKCE for both accounts; all fixture Post records unchanged."
