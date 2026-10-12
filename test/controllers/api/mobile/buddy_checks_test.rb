require "test_helper"
require_relative "../../../support/buddy_checks_helpers"

class MobileBuddyChecksTest < ActionDispatch::IntegrationTest
  include BuddyChecksHelpers
  setup { setup_buddy_checks }
  teardown { restore_buddy_configuration }
  BASE = "/api/mobile/v1/buddy-checks"

  test "ordinary members get bounded search and purpose-specific access without membership permission" do
    get "#{BASE}/people", params: { q: "Member", limit: 1 }, headers: mobile_headers
    assert_response :success
    assert_equal 1, response.parsed_body["items"].size
    assert response.parsed_body["next_cursor"]
    cursor = response.parsed_body["next_cursor"]
    get "#{BASE}/people", params: { q: "Member", cursor:, limit: 1 }, headers: mobile_headers
    assert_equal @unassigned.id, response.parsed_body["items"].sole["id"]
    get "#{BASE}/people", headers: mobile_headers
    assert_response :unprocessable_entity
    get "#{BASE}/people/#{@member.id}", headers: mobile_headers
    assert_response :success
    assert response.parsed_body.dig("eligibility", "eligible")
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_not @other.full_membership_access?
    get "/api/membership/workspace", headers: mobile_headers
    assert_response :unauthorized
    sign_in_as(@other)
    get "/api/membership/workspace", as: :json
    assert_response :forbidden
  end

  test "cookie and agent credentials cannot authenticate mobile requests and disabled credentials stop immediately" do
    sign_in_as(@other)
    get "/api/mobile/v1/session", as: :json
    assert_response :unauthorized
    _token, secret = AgentAccessToken.issue!(user: @other, name: "Agent", expires_in: 1.day)
    get "/api/mobile/v1/session", headers: { "Authorization" => "Bearer #{secret}" }
    assert_response :unauthorized
    headers = mobile_headers
    get "/api/mobile/v1/session", headers: headers
    assert_response :success
    @other.update!(disabled_at: Time.current)
    get "/api/mobile/v1/session", headers: headers
    assert_response :unauthorized
  end

  test "exact retries reconcile with immutable receipts but changed facts conflict" do
    payload = buddy_payload(follow_up: { due_at: 1.day.from_now.iso8601, entry_zone: "America/Chicago" })
    post BASE, params: payload, headers: mobile_headers, as: :json
    assert_response :created
    receipt = response.parsed_body
    assert_equal "accepted", receipt["state"]
    assert_equal "instant", receipt.dig("contact", "precision")
    assert_equal 1, MembershipContact.count
    assert_equal 1, BuddyFollowUp.count
    post BASE, params: payload, headers: mobile_headers, as: :json
    assert_response :created
    assert_equal receipt, response.parsed_body
    get "#{BASE}/receipts/#{payload[:operation_id]}", headers: mobile_headers
    assert_equal receipt, response.parsed_body
    post BASE, params: payload.deep_merge(facts: { outcome: "wrong_number" }), headers: mobile_headers, as: :json
    assert_response :conflict
    assert_equal "operation_payload_conflict", response.parsed_body.dig("error", "code")
    assert_equal 1, MembershipContact.count
    @member.update!(roster_removed_at: Time.current)
    get "#{BASE}/receipts/#{payload[:operation_id]}", headers: mobile_headers
    assert_response :not_found
    assert_not_includes response.body, "reached"
  end

  test "correction preserves original and replaces effective outcome in history and workspace across years" do
    @drive.update!(purpose: "buddy_check")
    payload = buddy_payload(assignment_id: @assignment.id, facts: buddy_facts(occurred_at: Time.utc(2025, 12, 31, 23).iso8601))
    post BASE, params: payload, headers: mobile_headers(@volunteer), as: :json
    assert_response :created
    id = response.parsed_body.dig("contact", "id")
    original = MembershipContact.find(id)
    original_attributes = original.attributes
    correction = { operation_id: SecureRandom.uuid, expected_revision: 1, facts: buddy_facts(outcome: "not_attempted") }
    post "#{BASE}/#{id}/corrections", params: correction, headers: mobile_headers(@volunteer), as: :json
    assert_response :created
    assert_equal 2, response.parsed_body.dig("contact", "revision")
    assert_equal @year, response.parsed_body.dig("contact", "membership_year")
    assert_equal original_attributes, original.reload.attributes
    assert_equal "not_attempted", MembershipContact.effective.sole.outcome
    assert workspace(@volunteer).contact_work_item(@member, purpose: "buddy_check", assignment: @assignment)[:outreach_needed]
    get "#{BASE}/mine", headers: mobile_headers(@volunteer)
    assert_equal [ "not_attempted" ], response.parsed_body["items"].pluck("outcome")
    get "#{BASE}/#{id}/revisions", headers: mobile_headers(@volunteer)
    assert_equal [ "reached", "not_attempted" ], response.parsed_body["items"].pluck("outcome")
    post "#{BASE}/#{id}/corrections", params: correction.merge(operation_id: SecureRandom.uuid), headers: mobile_headers(@volunteer), as: :json
    assert_response :conflict
    post "#{BASE}/#{id}/corrections", params: correction, headers: mobile_headers(@other), as: :json
    assert_response :not_found
  end

  test "follow-up changes are separate events and stale revisions cannot close rescheduled work" do
    payload = buddy_payload
    post BASE, params: payload, headers: mobile_headers, as: :json
    post "#{BASE}/follow-ups", params: { operation_id: SecureRandom.uuid, person_id: @member.id, due_at: 2.days.from_now.iso8601, entry_zone: "America/Chicago" }, headers: mobile_headers, as: :json
    assert_response :created
    id = response.parsed_body.dig("follow_up", "id")
    change = { operation_id: SecureRandom.uuid, expected_revision: 0, action: "reschedule", due_at: 3.days.from_now.iso8601, entry_zone: "America/Chicago" }
    post "#{BASE}/follow-ups/#{id}/changes", params: change, headers: mobile_headers, as: :json
    assert_response :created
    assert_equal 1, response.parsed_body.dig("follow_up", "revision")
    rescheduled = response.parsed_body
    post "#{BASE}/follow-ups/#{id}/changes", params: change, headers: mobile_headers, as: :json
    assert_response 201
    assert_equal rescheduled, response.parsed_body
    get "#{BASE}/receipts/#{change[:operation_id]}", headers: mobile_headers
    assert_response 200
    assert_equal rescheduled, response.parsed_body
    post "#{BASE}/follow-ups/#{id}/changes", params: { operation_id: SecureRandom.uuid, expected_revision: 0, action: "complete" }, headers: mobile_headers, as: :json
    assert_response :conflict
    post "#{BASE}/follow-ups/#{id}/changes", params: { operation_id: SecureRandom.uuid, expected_revision: 1, action: "complete" }, headers: mobile_headers, as: :json
    assert_response :created
    get "#{BASE}/follow-ups", headers: mobile_headers
    assert_equal "completed", response.parsed_body["items"].sole["status"]
    post "#{BASE}/follow-ups", params: { operation_id: SecureRandom.uuid, person_id: @member.id,
      due_at: 2.days.from_now.iso8601, entry_zone: "America/Chicago" }, headers: mobile_headers, as: :json
    cancelled_id = response.parsed_body.dig("follow_up", "id")
    post "#{BASE}/follow-ups/#{cancelled_id}/changes", params: { operation_id: SecureRandom.uuid,
      expected_revision: 0, action: "cancel" }, headers: mobile_headers, as: :json
    assert_response 201
    get "#{BASE}/follow-ups", params: { limit: 1 }, headers: mobile_headers
    assert_equal "completed", response.parsed_body["items"].sole["status"]
    assert_match(/\A\d+\z/, response.parsed_body["next_cursor"])
    get "#{BASE}/follow-ups", params: { limit: 1, cursor: response.parsed_body["next_cursor"] }, headers: mobile_headers
    assert_equal "cancelled", response.parsed_body["items"].sole["status"]
    assert_nil response.parsed_body["next_cursor"]
    assert_equal 1, MembershipContact.count
    get "#{BASE}/follow-ups", headers: mobile_headers(@volunteer)
    assert_empty response.parsed_body["items"]
  end

  test "snoozes are personal and undo requires a fresh revision and durable operation" do
    operation = { operation_id: SecureRandom.uuid, person_id: @member.id, until_at: 3.days.from_now.iso8601 }
    post "#{BASE}/snoozes", params: operation, headers: mobile_headers, as: :json
    assert_response :created
    receipt = response.parsed_body
    id = receipt.dig("snooze", "id")
    post "#{BASE}/snoozes", params: operation, headers: mobile_headers, as: :json
    assert_equal receipt, response.parsed_body
    delete "#{BASE}/snoozes/#{id}", params: { operation_id: SecureRandom.uuid, expected_revision: 0 }, headers: mobile_headers(@volunteer), as: :json
    assert_response :not_found
    undo = { operation_id: SecureRandom.uuid, expected_revision: 0 }
    delete "#{BASE}/snoozes/#{id}", params: undo, headers: mobile_headers, as: :json
    assert_response :created
    assert response.parsed_body.dig("snooze", "cancelled_at")
    assert_equal 1, BuddySnooze.count
  end

  test "private fields and other callers history never enter mobile results" do
    @member.update!(roster_address: "SECRET ADDRESS", member_number: "SECRET NUMBER")
    @drive.update!(purpose: "buddy_check")
    workspace.record_contact!(contact_attributes(notes: "SECRET NOTE", occurred_on: 100.days.ago.to_date))
    workspace.record_dues!(dues_attributes(notes: "SECRET MONEY"))
    [ "people/#{@member.id}", "suggestion", "mine" ].each do |path|
      get "#{BASE}/#{path}", headers: mobile_headers
      assert_response :success
      assert_not_includes response.body, "SECRET"
      assert_not_includes response.body, @officer.person.full_name
    end
  end

  test "directory-hidden assignment access ends when drive closes without giving renewal permissions" do
    @drive.update!(purpose: "buddy_check")
    @member.update!(roster_member_status: "Expired")
    get "#{BASE}/people/#{@member.id}", headers: mobile_headers(@volunteer)
    assert_response :success
    @drive.update!(closed_at: Time.current)
    get "#{BASE}/people/#{@member.id}", headers: mobile_headers(@volunteer)
    assert_response :not_found
  end

  test "every mobile mutation denies a disabled current human session before changing data" do
    headers = mobile_headers
    @other.update!(disabled_at: Time.current)
    routes = Rails.application.routes.routes.select do |route|
      route.defaults[:controller] == "api/mobile/v1/buddy_checks" && route.verb.match?(/POST|DELETE/)
    end
    assert_equal 6, routes.size
    routes.each do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)").gsub(":id", "1")
      public_send(route.verb == "DELETE" ? :delete : :post, path, params: buddy_payload, headers: headers, as: :json)
      assert_response :unauthorized
      assert_equal "account_unavailable", response.parsed_body.dig("error", "code")
    end
    assert_equal 0, BuddyOperation.count
    assert_equal 0, MembershipContact.count
  end

  test "malformed facts and unknown top-level fields return controlled validation errors" do
    [ buddy_payload(facts: []), buddy_payload(facts: nil), buddy_payload(unexpected: true),
      buddy_payload(facts: buddy_facts(notes: { private: "not a string" })) ].each do |payload|
      post BASE, params: payload, headers: mobile_headers, as: :json
      assert_response :unprocessable_entity
    end
    assert_equal 0, BuddyOperation.count
  end

  test "contact export is gated and invalidates structured addresses after source changes" do
    [ @other, @officer ].each { |user| user.permission_grants.create!(capability: "export_buddy_contacts") }
    @member.update!(roster_address: "Original flat source")
    BuddyAddressReview.create!(person: @member, reviewed_by: @officer, source_digest: BuddyAddressReview.source_digest(@member),
      source_note: "Synthetic reviewed mailing label", components: { "street" => "12 Example Way", "city" => "Example City" })
    path = "/api/mobile/v1/people/#{@member.id}/contact-export"
    get path, headers: mobile_headers
    assert_response :success
    assert_equal({}, response.parsed_body.dig("fields", "address"))
    assert_equal "Alex", response.parsed_body.dig("fields", "first_name")
    assert_not_includes response.body, "Original flat source"
    get path, headers: mobile_headers(@officer)
    assert_equal "Example City", response.parsed_body.dig("fields", "address", "city")
    version = response.parsed_body["version"]
    @member.update!(roster_address: "A changed source")
    get path, headers: mobile_headers(@officer)
    assert_equal({}, response.parsed_body.dig("fields", "address"))
    assert_not_equal version, response.parsed_body["version"]
    @member.update!(roster_address: "Original flat source")
    get path, headers: mobile_headers(@officer)
    assert_equal({}, response.parsed_body.dig("fields", "address"), "Restoring old text cannot revive an invalidated projection")
    ENV["MOBILE_CONTACT_EXPORT_ENABLED"] = "false"
    get path, headers: mobile_headers(@officer)
    assert_response :forbidden
  end

  test "export requires its own current grant without broadening directory or membership authority" do
    headers = mobile_headers(@officer)
    path = "/api/mobile/v1/people/#{@member.id}/contact-export"
    get path, headers: headers
    assert_response :forbidden
    assert_equal "export_not_permitted", response.parsed_body.dig("error", "code")
    get "/api/mobile/v1/session", headers: headers
    assert_equal false, response.parsed_body.dig("capabilities", "contacts_export")
    grant = @officer.permission_grants.create!(capability: "export_buddy_contacts")
    get path, headers: headers
    assert_response :success
    grant.destroy!
    get path, headers: headers
    assert_response :forbidden
    get "#{BASE}/people/#{@member.id}", headers: headers
    assert_equal false, response.parsed_body["export_available"]

    @drive.update!(purpose: "buddy_check")
    @member.update!(roster_member_status: "Expired")
    assigned_headers = mobile_headers(@volunteer)
    get path, headers: assigned_headers
    assert_response :forbidden
    @volunteer.permission_grants.create!(capability: "export_buddy_contacts")
    get path, headers: assigned_headers
    assert_response :forbidden
    assert_equal "export_not_permitted", response.parsed_body.dig("error", "code")
    assert_not @volunteer.full_membership_access?
    get "#{BASE}/people/#{@member.id}", headers: assigned_headers
    assert_response :success
  end

  test "suggestion reads apply exclusions and complete attendance without assigning or recording work" do
    entries = { @member.id.to_s => "absent", @unassigned.id.to_s => "present" }
    [ 20, 5 ].each do |days|
      BuddyAttendanceRegister.record!(meeting: buddy_meeting(days_ago: days), user: @officer,
        expected_revision: 0, entries:, complete: true, coverage_note: "Synthetic complete attendance.")
    end
    assert_no_difference [ "MembershipAssignment.count", "MembershipContact.count", "BuddyFollowUp.count", "BuddyOperation.count", "BuddySnooze.count" ] do
      get "#{BASE}/suggestion", headers: mobile_headers
      assert_response 200
      assert_equal "two_recorded_absences", response.parsed_body["reason"]
      assert_equal @member.id, response.parsed_body.dig("person", "id")
      assert_equal 2, response.parsed_body.dig("attendance", "meetings").size
      assert_not response.parsed_body.key?("random_candidates")
      get "#{BASE}/suggestion", params: { exclude_ids: [ @member.id ] }, headers: mobile_headers
      assert_response 200
      assert_equal "insufficient_history", response.parsed_body["state"]
      choices = response.parsed_body.fetch("random_candidates")
      assert_equal 3, choices.size
      assert_equal [ @unassigned.id, @officer.person_id, @volunteer.person_id ].sort, choices.pluck("id").sort
      choices.each { |identity| assert_equal %w[first_name id last_name], identity.keys.sort }
      assert_equal "unknown", response.parsed_body.dig("coverage", "missing_history")
      get "#{BASE}/suggestion", params: { exclude_ids: [ @member.id, @unassigned.id, @officer.person_id, @volunteer.person_id ] }, headers: mobile_headers
      assert_response 200
      assert_equal "exhausted", response.parsed_body["state"]
      assert_empty response.parsed_body.fetch("random_candidates", [])
    end
  end
end
