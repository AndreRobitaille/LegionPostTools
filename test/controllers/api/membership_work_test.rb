require "test_helper"
require_relative "../../support/membership_workspace_helpers"

class ApiMembershipWorkTest < ActionDispatch::IntegrationTest
  include MembershipWorkspaceHelpers

  setup { setup_membership_workspace }

  test "private worklist exposes assigned results but keeps individual officer notes private" do
    workspace.record_contact!(contact_attributes(membership_assignment_id: nil, notes: "Private officer review"))
    workspace.record_contact!(contact_attributes(notes: "Returned volunteer sheet", paper_reference: "#{@drive.id}-#{@assignment.id}-012345abcdef"))
    workspace(@volunteer).record_contact!(contact_attributes(notes: "Volunteer call"))
    @member.update!(roster_address: "Private address")
    sign_in_as(@volunteer)
    get "/api/membership/workspace", params: { membership_year: @year }, as: :json
    assert_response :success
    assert_equal [ @member.id ], response.parsed_body.fetch("people").pluck("id")
    assert_nil response.parsed_body["summary"]
    assert_equal "no-store", response.headers["Cache-Control"]
    get "/api/membership/workspace/people/#{@member.id}", params: { membership_year: @year }, as: :json
    assert_response :success
    assert_equal [ "Volunteer call", "Returned volunteer sheet" ], response.parsed_body.fetch("contacts").pluck("notes")
    [ @member.member_number, "Private address", "Private officer review" ].each { |secret| assert_not_includes response.body, secret }
    get "/api/membership/workspace/people/#{@unassigned.id}", as: :json
    assert_response :not_found
    get "/api/membership/workspace", params: { membership_year: @year - 1 }, as: :json
    assert_response :forbidden
  end

  test "bearer contact retry rechecks live assignment authority before replaying" do
    _token, secret = AgentAccessToken.issue!(user: @volunteer, name: "Synthetic caller", expires_in: 1.day)
    headers = { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => "record-call" }
    path = "/api/membership/workspace/people/#{@member.id}/contacts"
    payload = { membership_year: @year, membership_contact: contact_attributes(outcome: "already_paid_online") }
    post path, params: payload, headers:, as: :json
    assert_response :created
    first = response.parsed_body
    assert_equal "already_paid_online", first.dig("contact", "outcome")
    assert_no_difference [ "MembershipContact.count", "MembershipDuesRecord.count" ] do
      post path, params: payload, headers:, as: :json
      assert_response :created
      assert_equal first, response.parsed_body
    end
    @assignment.update!(revoked_at: Time.current)
    post path, params: payload, headers:, as: :json
    assert_response :forbidden
    assert_not_includes response.body, "already_paid_online"
    assert_equal 1, MembershipContact.count
  end

  test "paused contact and unassigned member mutation are denied without creating entries" do
    sign_in_as(@volunteer)
    workspace.record_contact!(contact_attributes(outcome: "do_not_contact"))
    assert_no_difference "MembershipContact.count" do
      post "/api/membership/workspace/people/#{@member.id}/contacts", params: { membership_contact: contact_attributes }, as: :json
      assert_response :forbidden
      post "/api/membership/workspace/people/#{@unassigned.id}/contacts", params: { membership_contact: contact_attributes }, as: :json
      assert_response :not_found
    end
    get "/api/membership/workspace", as: :json
    row = response.parsed_body.fetch("people").sole
    assert_nil row["phone_number"]
    assert_nil row["email_address"]
    assert_equal "held", row["work_state"]
  end

  test "handbook advertises assigned work only while current authority exists" do
    sign_in_as(@volunteer)
    get "/api", as: :json
    assert_response :success
    assert_includes response.body, "record_membership_contact"
    assert_not_includes response.body, '"name":"membership_summary"'
    @assignment.update!(revoked_at: Time.current)
    get "/api", as: :json
    assert_not_includes response.body, "record_membership_contact"
  end

  test "changing only the query year cannot replay a contact into another campaign" do
    _token, secret = AgentAccessToken.issue!(user: @officer, name: "Year-sensitive contact", expires_in: 1.day)
    headers = { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => "one-year-contact" }
    payload = { membership_contact: contact_attributes.except(:membership_assignment_id) }
    path = "/api/membership/workspace/people/#{@member.id}/contacts"
    post "#{path}?membership_year=#{@year - 1}", params: payload, headers:, as: :json
    assert_response :created
    assert_equal @year - 1, MembershipContact.sole.membership_year
    post "#{path}?membership_year=#{@year}", params: payload, headers:, as: :json
    assert_response :conflict
    assert_equal 1, MembershipContact.count
  end

  test "completed officer review and permission restoration retries require current officer authority" do
    @assignment.update!(assigned_to: @officer)
    _token, secret = AgentAccessToken.issue!(user: @officer, name: "Officer review", expires_in: 1.day)
    path = "/api/membership/workspace/people/#{@member.id}/contacts"
    submissions = [
      contact_attributes(channel: "administrative_review", outcome: "officer_review", notes: "Reviewed the returned result"),
      contact_attributes(outcome: "contact_permission_restored", notes: "Member requested renewed contact")
    ].map do |attributes|
      headers = { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => attributes[:submission_key] }
      payload = { membership_year: @year, membership_contact: attributes }
      post path, params: payload, headers:, as: :json
      assert_response :created
      [ headers, payload ]
    end
    @office.update!(ends_on: Organization.current_local_date - 1)
    assert workspace(@officer).access.permitted?, "The former officer still has a caller assignment"
    assert_no_difference "MembershipContact.count" do
      submissions.each do |headers, payload|
        post path, params: payload, headers:, as: :json
        assert_response :forbidden
        assert_not_includes response.body, "Reviewed the returned result"
      end
    end
  end

  test "renewal opt out leaves a separately assigned Buddy Check contact available" do
    workspace.record_contact!(contact_attributes(outcome: "do_not_contact"))
    @assignment.update!(revoked_at: Time.current)
    buddy = @organization.membership_drives.create!(title: "Buddy Checks", purpose: "buddy_check", membership_year: @year,
      starts_on: @drive.starts_on, ends_on: @drive.ends_on, created_by: @officer)
    assignment = buddy.assignments.create!(person: @member, assigned_to: @volunteer, assigned_by: @officer, expires_on: buddy.ends_on)
    sign_in_as(@volunteer)
    get "/api/membership/workspace/people/#{@member.id}", params: { membership_year: @year, assignment_id: assignment.id }, as: :json
    assert_response :success
    row = response.parsed_body.fetch("person")
    assert_equal "buddy_check", row["contact_purpose"]
    assert_not row["contact_paused"]
    assert_equal @member.directory_phone_number, row["phone_number"]
  end

  test "a deceased roster update suppresses contact data and rejects a completed officer bearer retry" do
    _token, secret = AgentAccessToken.issue!(user: @officer, name: "Officer retained history", expires_in: 1.day)
    headers = { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => "before-deceased" }
    path = "/api/membership/workspace/people/#{@member.id}"
    payload = { membership_year: @year, membership_contact: contact_attributes(notes: "Earlier contact") }
    post "#{path}/contacts", params: payload, headers:, as: :json
    assert_response :created
    @member.update!(roster_member_status: "Deceased")
    get path, params: { membership_year: @year }, headers: headers.except("Idempotency-Key"), as: :json
    assert_response :success
    row = response.parsed_body.fetch("person")
    assert_equal "no_outreach", row["work_state"]
    assert_not row["needs_attention"]
    assert_not row["outreach_needed"]
    assert_nil row["phone_number"]
    assert_nil row["email_address"]
    assert_equal "Earlier contact", response.parsed_body.fetch("contacts").sole["notes"]
    assert_no_difference "MembershipContact.count" do
      post "#{path}/contacts", params: payload, headers:, as: :json
      assert_response :forbidden
      assert_not_includes response.body, "Earlier contact"
    end
    sign_in_as(@volunteer)
    get path, params: { membership_year: @year }, as: :json
    assert_response :forbidden
  end
end
