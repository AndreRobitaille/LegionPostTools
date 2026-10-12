require_relative "buddy_authority_fixture"
require_relative "buddy_mobile_probe"

raise "Rehearsal database only" unless ActiveRecord::Base.connection_db_config.database == "legion_buddy_authority_verify_test"
ActiveRecord::Base.connection.disable_query_cache!
control = BuddyAuthorityFixture.new
fixture = control.fixture
people = fixture.fetch("people")
state = control.status
expected_count = ENV["BUDDY_AUTHORITY_RESUME_MEMBER"] == "true" ? 3 : 2
raise "Consumed rehearsal: inspect evidence; never reset or replay blindly" unless state[:contacts] == expected_count && state[:receipts] == expected_count &&
  state[:registers].empty? && !state[:paused] && state[:reviewer_authorized] && state[:assignments].none? { |row| row["person_id"] == people.fetch("coordination") }
caller = BuddyMobileProbe.new
reviewer = BuddyMobileProbe.new
caller.sign_in(User.find(fixture.fetch("caller_id")), use_code: true)
reviewer.sign_in(User.find(fixture.fetch("reviewer_id")), use_code: true)
handbook = caller.request("get", "/api")
raise "Authenticated handbook unavailable" unless handbook.code == "200"
File.open(File.join(File.dirname(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE")), "caller-handbook.md"), "wb", 0o600) { |file| file.write(handbook.body) }
checks = 0
check = ->(condition, message) { checks += 1; raise message unless condition }
base = "/buddy-checks"
card = ->(key) { caller.api("get", "#{base}/people/#{people.fetch(key)}") }
export = ->(probe, key, status = 200) { probe.api("get", "/people/#{people.fetch(key)}/contact-export", status:) }
advance = ->(action) { control.advance!(action, checkpoint: "Backend HTTPS rehearsal checkpoint for #{action}; not a native observation") }
payload = ->(key) { { operation_id: SecureRandom.uuid, person_id: people.fetch(key),
  facts: { channel: "phone", outcome: "no_answer", occurred_at: 1.minute.ago.iso8601(6), entry_zone: "America/Chicago" } } }
error = ->(body, code) { check.call(body.dig("error", "code") == code, "Expected #{code}") }
unknown = ->(operation) do
  error.call(caller.api("get", "#{base}/receipts/#{operation.fetch(:operation_id)}", status: 404), "not_found")
  evidence = control.reconcile(user_id: fixture.fetch("caller_id"), person_id: operation.fetch(:person_id), operation_id: operation.fetch(:operation_id))
  check.call(evidence.fetch(:operation_rows).zero?, "Rejected/unsent UUID has an accepted operation")
end
rejected = ->(operation, status, code) do
  before = [ MembershipContact.count, BuddyOperation.count ]
  error.call(caller.api("post", base, status:, body: operation), code)
  unknown.call(operation)
  check.call(before == [ MembershipContact.count, BuddyOperation.count ], "Rejected POST changed contacts/receipts")
end
explicit_retry = ->(operation) do
  before = [ MembershipContact.count, BuddyOperation.count ]
  receipt = caller.api("post", base, status: 201, body: operation)
  check.call(receipt["state"] == "accepted", "Explicit retry was not accepted")
  check.call([ before[0] + 1, before[1] + 1 ] == [ MembershipContact.count, BuddyOperation.count ], "Retry did not create exactly one check/receipt")
  check.call(caller.api("get", "#{base}/receipts/#{operation.fetch(:operation_id)}") == receipt, "Receipt mismatch")
  check.call(caller.api("post", base, status: 201, body: operation) == receipt, "Exact retry changed receipt")
  check.call([ before[0] + 1, before[1] + 1 ] == [ MembershipContact.count, BuddyOperation.count ], "Exact retry duplicated work")
end
isolate = ->(key) do
  excluded = Person.pluck(:id) - [ people.fetch(key) ]
  caller.api("get", "#{base}/suggestion?#{ { exclude_ids: excluded }.to_query }")
end
baseline_contacts = MembershipContact.order(:id).map(&:attributes)
baseline_operations = BuddyOperation.order(:id).map(&:attributes)

if ENV["BUDDY_AUTHORITY_RESUME_MEMBER"] == "true"
  # Only resume the observed first accepted member operation; do not invent a new UUID.
  accepted = BuddyOperation.where(user_id: fixture.fetch("caller_id"), person_id: people.fetch("member")).sole
  contact = MembershipContact.find(accepted.receipt.dig("contact", "id"))
  operation = { operation_id: accepted.operation_id, person_id: contact.person_id, assignment_id: contact.membership_assignment_id,
    facts: { channel: contact.channel, outcome: contact.outcome, occurred_at: contact.occurred_at.iso8601(6), entry_zone: contact.entry_zone } }
  before = [ MembershipContact.count, BuddyOperation.count ]
  check.call(caller.api("get", "#{base}/receipts/#{accepted.operation_id}") == accepted.receipt, "Interrupted receipt changed")
  check.call(caller.api("post", base, status: 201, body: operation) == accepted.receipt, "Exact reconstructed retry changed receipt/body")
  check.call(before == [ MembershipContact.count, BuddyOperation.count ], "Resumed retry duplicated accepted work")
  puts "PASS: resumed the previously accepted explicit-assignment UUID/body; no reset or duplicate"
else
  operation = payload.call("member").merge(assignment_id: fixture.fetch("member_assignment_id"))
  check.call(card.call("member").dig("eligibility", "eligible"), "Initial assignment not readable/eligible")
  error.call(export.call(caller, "member", 403), "export_not_permitted")
  advance.call("member_end")
  error.call(caller.api("get", "#{base}/people/#{people.fetch('member')}", status: 404), "not_found")
  check.call(caller.api("get", "#{base}/people?q=Avery")["items"].empty?, "Hidden recipient remained searchable")
  error.call(export.call(caller, "member", 404), "not_found")
  rejected.call(operation, 404, "not_found")
  advance.call("member_restore")
  restored = card.call("member")
  check.call(restored.dig("eligibility", "eligible"), "Restored assignment not readable")
  unknown.call(operation) # Backend restoration cannot accept a retained draft.
  rejected.call(operation, 404, "not_found") # The ended assignment ID stays ended.
  operation[:assignment_id] = restored.fetch("assignment_ids").sole
  explicit_retry.call(operation) # Simulated explicit client retry; same UUID and facts.
  puts "PASS: assignment scope, search/export denial, stale assignment, no receipt on denial, explicit retry exactly once"
end

# The current native client omits assignment_id. Its exact body/UUID survives a
# scope-denied attempt and can be explicitly retried after a NEW assignment exists.
operation = payload.call("member")
original_body = JSON.generate(operation)
advance.call("member_end")
rejected.call(operation, 404, "not_found")
advance.call("member_restore")
unknown.call(operation)
check.call(JSON.generate(operation) == original_body && !operation.key?(:assignment_id), "Omitted-ID retry body changed")
explicit_retry.call(operation)
accepted = BuddyOperation.find_by!(operation_id: operation.fetch(:operation_id))
contact = MembershipContact.find(accepted.receipt.dig("contact", "id"))
check.call(contact.membership_assignment_id.nil?, "Omitted ID unexpectedly attached an assignment")
check.call(contact.membership_year == contact.occurred_on.year, "Omitted ID used drive year instead of event year")
puts "PASS: native omitted-assignment-ID body/UUID unchanged across denied POST, restoration, explicit retry and exact replay"

operation = payload.call("pause")
baseline_receipt = fixture.fetch("baseline_receipt_ids").fetch("pause")
check.call(card.call("pause")["phone"].present?, "Initial pause case lacks phone")
check.call(export.call(caller, "pause")["permitted_fields"].include?("phone"), "Initial pause export missing")
advance.call("pause_on")
paused = card.call("pause")
check.call(paused.dig("eligibility", "reason") == "contact_paused" && paused["phone"].nil? && paused["email"].nil?, "Pause did not hide card actions")
check.call(caller.api("get", "#{base}/people?q=Parker")["items"].pluck("id") == [ people.fetch("pause") ], "Pause unexpectedly hid identity")
error.call(export.call(caller, "pause", 403), "contact_paused")
error.call(caller.api("get", "#{base}/receipts/#{baseline_receipt}", status: 403), "contact_paused")
rejected.call(operation, 403, "contact_paused")
advance.call("pause_restore")
check.call(card.call("pause").dig("eligibility", "eligible"), "Permission restoration failed")
check.call(export.call(caller, "pause")["permitted_fields"].include?("phone"), "Export did not recover")
check.call(caller.api("get", "#{base}/receipts/#{baseline_receipt}")["state"] == "accepted", "Original receipt did not recover")
unknown.call(operation)
explicit_retry.call(operation)
puts "PASS: audited purpose pause/restoration, current projection, denied save, old receipt preserved and recovered"

check.call(isolate.call("coordination").dig("person", "id") == people.fetch("coordination"), "Initial coordination candidate missing")
advance.call("coordination_assign")
coordinated = card.call("coordination")
check.call(coordinated.dig("eligibility", "reason") == "assigned_elsewhere" && coordinated["phone"].nil?, "Other assignment did not defer outreach")
check.call(isolate.call("coordination")["state"] == "exhausted", "Other assignment still suggested")
check.call(export.call(caller, "coordination")["permitted_fields"].include?("phone"), "Directory export contract changed")
check.call(caller.api("get", "#{base}/mine")["items"].none? { |row| row["person_id"] == people.fetch("coordination") }, "Other caller history leaked")
other_contact = BuddyOperation.find_by!(operation_id: fixture.fetch("baseline_receipt_ids").fetch("coordination")).receipt.dig("contact", "id")
error.call(caller.api("get", "#{base}/#{other_contact}/revisions", status: 404), "not_found")
advance.call("coordination_end")
check.call(isolate.call("coordination").dig("person", "id") == people.fetch("coordination"), "Ended assignment did not recover suggestion")
puts "PASS: coordination deferral/recovery and private-history separation"

session = reviewer.api("get", "/session")
full = export.call(reviewer, "export")
check.call(full["address_coverage"] == "reviewed_components" && full["permitted_fields"].include?("address"), "Initial address tier missing")
advance.call("tier_remove")
reduced = export.call(reviewer, "export")
check.call(reduced["fields"]["address"] == {} && !reduced["permitted_fields"].include?("address") && reduced["address_review_id"].nil? && reduced["address_coverage"] == "not_permitted", "Reduced authority leaked address")
check.call(full["version"] != reduced["version"], "Authority change did not change projection version")
check.call(reviewer.api("get", "/session")["session_id"] == session["session_id"], "Authority check replaced the mobile session")
advance.call("tier_restore")
restored = export.call(reviewer, "export")
check.call(restored["fields"] == full["fields"] && restored["version"] == full["version"], "Restored tier did not recover original reviewed projection")
puts "PASS: same-session authority reduction/restoration; native Contacts write enforcement remains a mobile check"

check.call(isolate.call("attendance")["state"] == "insufficient_history", "Missing attendance implied absence")
%w[attendance_incomplete attendance_first_absence].each do |action|
  advance.call(action)
  check.call(isolate.call("attendance")["state"] == "insufficient_history", "Incomplete or single absence implied two absences")
end
advance.call("attendance_two_absences")
candidate = isolate.call("attendance")
check.call(candidate.dig("person", "id") == people.fetch("attendance") && candidate["reason"] == "two_recorded_absences", "Two complete absences missing")
meetings = fixture.fetch("meeting_ids").map { |id| Meeting.find(id) }.sort_by(&:starts_at).reverse
check.call(candidate["reason_on"] == meetings.first.starts_at.in_time_zone("America/Chicago").to_date.iso8601, "Wrong absence reason date")
check.call(candidate.dig("attendance", "meetings").pluck("meeting_id") == meetings.map(&:id) && candidate.dig("attendance", "meetings").pluck("register_revision") == [ 2, 2 ], "Wrong absence evidence revisions")
registers = BuddyAttendanceRegister.order(:id).map(&:attributes)
%w[attendance_present attendance_excused].each do |action|
  advance.call(action)
  check.call(isolate.call("attendance")["state"] == "insufficient_history", "Correction retained absence claim")
end
check.call(BuddyAttendanceRegister.order(:id).limit(registers.size).map(&:attributes) == registers, "Earlier registers changed")
check.call(MembershipContact.order(:id).limit(baseline_contacts.size).map(&:attributes) == baseline_contacts, "Baseline accepted contacts changed")
check.call(BuddyOperation.order(:id).limit(baseline_operations.size).map(&:attributes) == baseline_operations, "Baseline receipts changed")
check.call(MeetingMinutes.count.zero?, "Attendance created minutes")
puts "PASS: missing/incomplete/single/two absences, dated evidence, append-only present/excused corrections"

[ caller, reviewer ].each do |probe|
  check.call(probe.request("post", "/oauth/revoke", form: { client_id: fixture.fetch("client_id"), token: probe.token }).code == "200", "Probe token revocation failed")
end
puts "PASS: #{checks} explicit acceptance assertions over verified HTTPS; rehearsal only. No native result claimed."
