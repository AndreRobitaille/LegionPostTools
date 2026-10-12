require_relative "buddy_mobile_probe"

raise "Synthetic integration database required" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "legion_buddy_mobile_test"
raise "Synthetic installation required" unless Organization.sole.name == "Example American Legion Post"
# The server commits on another connection; runner query caching would hide those writes.
ActiveRecord::Base.connection.disable_query_cache!


fixture = JSON.parse(File.read(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE")))
caller = User.find(fixture.fetch("caller_id"))
officer = User.find(fixture.fetch("officer_id"))
people = fixture.fetch("people")
recipient = Person.find(people.fetch("Blair"))
resume_id = ENV["BUDDY_MOBILE_RESUME_OPERATION_ID"].presence
resumed = BuddyOperation.find_by!(operation_id: resume_id, user: caller, person: recipient) if resume_id
if resumed
  raise "Only an interrupted first submission can be resumed" unless MembershipContact.where(person: recipient).count == 1 &&
    resumed.receipt.dig("contact", "outcome") == "no_answer" &&
    BuddyFollowUp.find(resumed.receipt.dig("follow_up", "id")).lock_version.zero?
elsif MembershipContact.exists?(person: recipient)
  raise "Use an untouched Blair fixture; this probe never resets accepted evidence"
end
probe = BuddyMobileProbe.new
probe.sign_in(caller)
unless resumed
  page = probe.api("get", "/buddy-checks/people?q=Example&limit=2")
  probe.assert(page.fetch("items").size == 2 && page["next_cursor"], "Search was not paginated")
  probe.assert(page.fetch("items").all? { |item| item.keys.sort == %w[first_name id last_name] }, "Search exposed private fields")
  next_page = probe.api("get", "/buddy-checks/people?q=Example&limit=2&cursor=#{page.fetch('next_cursor')}")
  probe.assert((page["items"].pluck("id") & next_page["items"].pluck("id")).empty?, "Pagination duplicated rows")
  card = probe.api("get", "/buddy-checks/people/#{recipient.id}")
  probe.assert(card.dig("eligibility", "eligible"), "Untouched synthetic person was not eligible")
  suggestion = probe.api("get", "/buddy-checks/suggestion")
  probe.assert(suggestion["reason"] == "two_recorded_absences" && suggestion.dig("person", "id") == people.fetch("Morgan"), "Complete absence evidence was not selected")
  exclusions = people.except("Blair").values.map { |id| "exclude_ids[]=#{id}" }.join("&")
  unknown = probe.api("get", "/buddy-checks/suggestion?#{exclusions}")
  probe.assert(unknown["state"] == "insufficient_history", "Missing history was not reported honestly")
  BuddyAddressReview.create!(person: recipient, reviewed_by: officer, source_digest: BuddyAddressReview.source_digest(recipient),
    source_note: "Synthetic structured mailing label for live integration only", components: { "street" => "99 Example Way" })
  export = probe.api("get", "/people/#{recipient.id}/contact-export")
  probe.assert(export.dig("fields", "address") == {} && export["address_coverage"] == "not_permitted", "Ordinary export exposed address")
end
reviewer = BuddyMobileProbe.new
reviewer.sign_in(officer)
reviewed_export = reviewer.api("get", "/people/#{recipient.id}/contact-export")
probe.assert(reviewed_export.dig("fields", "address", "street") == "99 Example Way", "Officer export omitted reviewed address")
puts(resumed ? "Resuming an interrupted probe; initial search/evidence/export checks were already observed." :
  "PASS: bounded search, fresh eligibility, unknown history, complete absences and export tiers")

key = resumed&.operation_id || SecureRandom.uuid
facts = resumed ? resumed.receipt.fetch("contact").slice("channel", "outcome", "occurred_at", "entry_zone").symbolize_keys :
  { channel: "phone", outcome: "no_answer", occurred_at: 1.minute.ago.iso8601(6), entry_zone: "America/Chicago" }
due_at = resumed ? resumed.receipt.dig("follow_up", "due_at") : 2.days.from_now.iso8601(6)
payload = { operation_id: key, person_id: recipient.id, facts:,
  follow_up: { due_at:, entry_zone: "America/Chicago" } }
before = MembershipContact.count - (resumed ? 1 : 0)
# Treat the first response as lost; reconcile by UUID before reading effective history.
probe.api("post", "/buddy-checks", status: 201, body: payload)
receipt = probe.api("get", "/buddy-checks/receipts/#{key}")
repeated = probe.api("post", "/buddy-checks", status: 201, body: payload)
probe.assert(repeated == receipt && MembershipContact.count == before + 1, "Retry duplicated accepted work")
probe.assert(BuddyOperation.where(user: caller, operation_id: key).count == 1, "Retry duplicated receipts")
conflict = probe.api("post", "/buddy-checks", status: 409, body: payload.deep_merge(facts: { outcome: "wrong_number" }))
probe.assert(conflict.dig("error", "code") == "operation_payload_conflict", "Changed payload did not conflict")
original = receipt.fetch("contact")
correction = probe.api("post", "/buddy-checks/#{original.fetch('id')}/corrections", status: 201,
  body: { operation_id: SecureRandom.uuid, expected_revision: 1, facts: facts.merge(outcome: "wrong_number") })
probe.assert(MembershipContact.find(original.fetch("source_id")).outcome == "no_answer", "Correction rewrote the original")
probe.assert(correction.dig("contact", "revision") == 2 && MembershipContact.effective.where(person: recipient).sole.outcome == "wrong_number", "Effective correction was not persisted")
follow_up = receipt.fetch("follow_up")
changed = probe.api("post", "/buddy-checks/follow-ups/#{follow_up.fetch('id')}/changes", status: 201,
  body: { operation_id: SecureRandom.uuid, expected_revision: 0, action: "reschedule", due_at: 3.days.from_now.iso8601(6), entry_zone: "America/Chicago" })
probe.assert(changed.dig("follow_up", "revision") == 1, "Follow-up revision did not advance")
probe.api("post", "/buddy-checks/follow-ups/#{follow_up.fetch('id')}/changes", status: 409,
  body: { operation_id: SecureRandom.uuid, expected_revision: 0, action: "complete" })
probe.api("post", "/buddy-checks/follow-ups/#{follow_up.fetch('id')}/changes", status: 201,
  body: { operation_id: SecureRandom.uuid, expected_revision: 1, action: "complete" })
scheduled = probe.api("post", "/buddy-checks/follow-ups", status: 201,
  body: { operation_id: SecureRandom.uuid, person_id: recipient.id, due_at: 2.days.from_now.iso8601(6), entry_zone: "America/Chicago" })
cancelled = probe.api("post", "/buddy-checks/follow-ups/#{scheduled.dig('follow_up', 'id')}/changes", status: 201,
  body: { operation_id: SecureRandom.uuid, expected_revision: 0, action: "cancel" })
probe.assert(cancelled.dig("follow_up", "status") == "cancelled" && MembershipContact.count == before + 2, "Closing follow-ups changed contacts")
snooze = probe.api("post", "/buddy-checks/snoozes", status: 201,
  body: { operation_id: SecureRandom.uuid, person_id: people.fetch("Alex"), until_at: 1.day.from_now.iso8601(6) })
undone = probe.api("delete", "/buddy-checks/snoozes/#{snooze.dig('snooze', 'id')}", status: 201,
  body: { operation_id: SecureRandom.uuid, expected_revision: 0 })
probe.assert(undone.dig("snooze", "cancelled_at").present? && BuddySnooze.find(snooze.dig("snooze", "id")).cancelled_at, "Snooze undo was not persisted")
probe.assert(probe.api("get", "/buddy-checks/receipts/#{key}") == receipt, "Correction changed the original receipt")
puts "PASS: persisted contact #{original.fetch('id')}, lost-response reconciliation, retry/conflict, immutable correction, follow-up lifecycle, snooze/undo"

token = Doorkeeper::AccessToken.by_token(probe.token)
token.update!(created_at: 16.minutes.ago)
expired = probe.api("get", "/session", status: 401)
probe.assert(expired.dig("error", "code") == "expired_session", "Expired session was not distinguished")
revoked = reviewer.request("post", "/oauth/revoke", form: { client_id: ENV.fetch("MOBILE_BUDDY_CHECK_CLIENT_ID"), token: reviewer.token })
probe.assert(revoked.code == "200", "Revocation failed")
probe.assert(reviewer.api("get", "/session", status: 401).dig("error", "code") == "revoked_session", "Confirmed revocation was not distinguished")
puts "PASS: persisted-token expiry and explicit OAuth revocation reject subsequent HTTPS requests"
puts "Evidence remains in the synthetic database; this probe does not reset it. Device/Swift behavior remains unverified."
