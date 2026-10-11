require "test_helper"
require_relative "../support/membership_workspace_helpers"

class MembershipWorkspaceControllerTest < ActionDispatch::IntegrationTest
  include MembershipWorkspaceHelpers

  setup { setup_membership_workspace }

  test "officer completes local payment correction and frozen Adjutant summary through the website" do
    sign_in_as(@officer)
    get membership_root_path, params: { membership_year: @year }
    assert_response :success
    assert_select ".membership-task", count: 2
    assert_select ".membership-summary", count: 0
    assert_select "form[action='#{membership_dues_records_path}']", count: 0
    assert_equal "no-store", response.headers["Cache-Control"]

    post membership_dues_records_path, params: { membership_year: @year, membership_dues_record: dues_attributes }
    assert_response :see_other
    follow_redirect!
    assert_includes response.body, "Post received dues; confirm with National"
    assert_equal @year - 1, @member.reload.roster_paid_through_year
    receipt = @member.membership_dues_records.sole

    post membership_summaries_path, params: { membership_year: @year, submission_key: "saved-summary" }
    assert_response :see_other
    follow_redirect!
    assert_includes response.body, "$45.00"
    snapshot = MembershipSummary.sole
    post reverse_membership_dues_record_path(receipt), params: { correction: { notes: "Receipt entered twice on paper", submission_key: "correction" } }
    assert_response :see_other
    follow_redirect!
    assert_includes response.body, "Renewal follow-up needed"
    get membership_summary_path(snapshot)
    assert_includes response.body, "$45.00"
    assert_equal "45.0", snapshot.reload.payload["post_dues_received"]
  end

  test "Membership is absent from both navigation surfaces without current role or assigned access" do
    sign_in_as(@other)
    get root_path
    assert_response :success
    assert_select "a[href='#{membership_root_path}']", count: 0
    get membership_root_path
    assert_response :forbidden

    @assignment.update!(assigned_to: @other)
    get root_path
    assert_response :success
    assert_select "a[href='#{membership_root_path}']", count: 2
    get membership_report_path
    assert_response :forbidden
    get membership_post_checks_path
    assert_response :forbidden
    @drive.update!(closed_at: Time.current)
    get root_path
    assert_select "a[href='#{membership_root_path}']", count: 0

    sign_in_as(@officer)
    get root_path
    assert_select "a[href='#{membership_root_path}']", count: 2
    @office.update!(ends_on: Organization.current_local_date - 1)
    get root_path
    assert_select "a[href='#{membership_root_path}']", count: 0
  end

  test "default worklist excludes completed or deferred work and keeps actionable verification" do
    @member.update!(roster_paid_through_year: @year)
    callback_member = membership_person("Callback", 3)
    later_member = membership_person("Later", 4)
    paused_member = membership_person("Paused", 5)
    declined_member = membership_person("Declined", 6)
    received_member = membership_person("Received", 7)
    online_member = membership_person("Online", 8)
    [ [ callback_member, Organization.current_local_date ], [ later_member, Organization.current_local_date + 3 ] ].each do |person, date|
      workspace.record_contact!(contact_attributes(person_id: person.id, membership_assignment_id: nil, outcome: "callback_requested", follow_up_on: date))
    end
    workspace.record_contact!(contact_attributes(person_id: paused_member.id, membership_assignment_id: nil, outcome: "do_not_contact"))
    workspace.record_contact!(contact_attributes(person_id: declined_member.id, membership_assignment_id: nil, outcome: "declined_renewal"))
    workspace.record_dues!(dues_attributes(person_id: received_member.id))
    workspace.record_dues!(dues_attributes(person_id: online_member.id, kind: "national_reported", amount: nil))
    sign_in_as(@officer)
    get membership_root_path
    assert_response :success
    assert_select "select[name='filter'] option[selected][value='attention']"
    names = css_select(".membership-task .mrow-name").map(&:text)
    assert_equal [ callback_member, online_member, received_member, @unassigned ].map(&:roster_display_name), names
    assert_select ".membership-task-action p", text: "Verify the member's online renewal"
    assert_includes response.body, "Confirm dues received here with National"

    get membership_root_path, params: { filter: "all" }
    assert_response :success
    assert_select ".membership-task", count: 8
    [ @member, later_member, paused_member, declined_member ].each do |person|
      assert_select ".membership-task .mrow-name", text: person.roster_display_name
    end
    get membership_root_path, params: { q: "Later" }
    assert_select ".membership-task", count: 0
    assert_select "a", text: "Show all members"
  end

  test "report and Post check work have separate officer pages with year and correction recovery" do
    sign_in_as(@officer)
    get membership_report_path, params: { membership_year: @year }
    assert_response :success
    assert_select ".membership-summary", count: 1
    assert_includes response.body, "Paid for #{@year}"
    assert_includes response.body, "Members who paid the Post"
    assert_includes response.body, "We received their dues, but National's roster has not confirmed"
    assert_select ".membership-task", count: 0
    get membership_post_checks_path, params: { membership_year: @year }
    assert_response :success
    assert_select ".membership-summary", count: 0
    attributes = dues_attributes(person_id: nil, kind: "post_share_received", amount: "not-money")
    post membership_dues_records_path, params: { membership_year: @year, membership_dues_record: attributes }
    assert_response :unprocessable_entity
    assert_includes response.body, "Post checks"
    assert_select "input[name='membership_dues_record[submission_key]'][value='#{attributes[:submission_key]}']"
    post membership_dues_records_path, params: { membership_year: @year, membership_dues_record: attributes.merge(amount: "130.25") }
    assert_redirected_to membership_post_checks_path(membership_year: @year)
    follow_redirect!
    assert_includes response.body, "$130.25"
    assert_equal @year - 1, @member.reload.roster_paid_through_year
  end

  test "deceased and removed members stay out of follow up while officers retain their history" do
    workspace.record_contact!(contact_attributes(outcome: "callback_requested", follow_up_on: Organization.current_local_date, notes: "Earlier agreed callback"))
    sign_in_as(@officer)
    [ { roster_member_status: "Deceased" }, { roster_member_status: "Active", roster_removed_at: Time.current } ].each do |change|
      @member.update!(change)
      get membership_root_path
      assert_response :success
      assert_select ".membership-task .mrow-name", text: @member.roster_display_name, count: 0
      get membership_root_path, params: { filter: "all" }
      assert_select ".membership-task .mrow-name", text: @member.roster_display_name
      assert_includes response.body, "no outreach"
      get membership_person_path(@member)
      assert_response :success
      assert_includes response.body, "Earlier agreed callback"
      assert_select "a[href^='tel:'], a[href^='mailto:']", count: 0
      assert_no_difference "MembershipContact.count" do
        post membership_person_contacts_path(@member), params: { membership_year: @year, membership_contact: contact_attributes(membership_assignment_id: nil) }
        assert_response :forbidden
      end
      get membership_report_path
      assert_select ".membership-counts dt", text: /Deceased or removed records/
      assert_select ".membership-counts dt", text: /Membership records to check.*Missing payment information/m
    end
    review = contact_attributes(membership_assignment_id: nil, channel: "administrative_review", outcome: "officer_review", notes: "Reviewed retained history")
    post membership_person_contacts_path(@member), params: { membership_year: @year, membership_contact: review }
    assert_response :see_other
    follow_redirect!
    assert_includes response.body, "Reviewed retained history"
    assert_equal 2, @member.membership_contacts.count
    assert_not workspace.work_item(@member.reload)[:needs_attention]

    legacy_payload = workspace.summary
    legacy_payload[:work_counts].delete("no_outreach")
    legacy_payload[:work_counts]["review"] = 1
    legacy = @organization.membership_summaries.create!(created_by: @officer, membership_year: @year, payload: legacy_payload, submission_key: "earlier-summary-definition")
    get membership_summary_path(legacy)
    assert_response :success
    assert_includes response.body, "As saved: includes deceased and removed records"
    assert_equal 1, legacy.reload.payload.dig("work_counts", "review")
  end

  test "fresh renewal call sheets omit no longer actionable assignments and keep due and expired members" do
    excluded = %w[Deceased Removed Paid Paused Declined Later Uncertain].each_with_index.map do |name, index|
      person = membership_person(name, index + 3)
      assignment = @drive.assignments.create!(person:, assigned_to: @volunteer, assigned_by: @officer, expires_on: @drive.ends_on)
      case name
      when "Deceased" then person.update!(roster_member_status: "Deceased")
      when "Removed" then person.update!(roster_removed_at: Time.current)
      when "Paid" then person.update!(roster_paid_through_year: @year)
      when "Uncertain" then person.update!(roster_paid_through_year: nil)
      else
        outcome = { "Paused" => "do_not_contact", "Declined" => "declined_renewal", "Later" => "callback_requested" }.fetch(name)
        workspace.record_contact!(contact_attributes(person_id: person.id, membership_assignment_id: assignment.id,
          outcome:, follow_up_on: outcome == "callback_requested" ? Organization.current_local_date + 3 : nil))
      end
      person
    end
    @member.update!(roster_member_status: "Expired")
    workspace.record_contact!(contact_attributes(outcome: "callback_requested", follow_up_on: Organization.current_local_date))
    sign_in_as(@officer)
    token = MembershipPdf.source_token(organization: @organization, user: @officer, drive: @drive)
    get "/internal/membership-pdf-source", params: { token: }
    assert_response :success
    assert_includes response.body, @member.roster_display_name
    excluded.each { |person| assert_not_includes response.body, person.roster_display_name }
    assert_equal 8, @drive.assignments.count, "Printing must preserve assignment history"
  end

  test "volunteer records callback and officer transcribes older sheet without replacing newer work" do
    sign_in_as(@volunteer)
    get membership_root_path, params: { membership_year: @year }
    assert_response :success
    assert_includes response.body, @member.full_name
    assert_not_includes response.body, @unassigned.full_name
    get membership_person_path(@member), params: { membership_year: @year }
    assert_response :success
    assert_not_includes response.body, "Full-year dues received by the Post"
    assert_not_includes response.body, @member.member_number
    attributes = contact_attributes(outcome: "callback_requested", follow_up_on: Organization.current_local_date + 3, notes: "Call after lunch")
    post membership_person_contacts_path(@member), params: { membership_year: @year, membership_contact: attributes }
    assert_response :see_other
    follow_redirect!
    assert_includes response.body, "Call after lunch"
    newest = MembershipContact.sole
    sign_in_as(@officer)
    post membership_person_contacts_path(@member), params: { membership_year: @year, membership_contact: contact_attributes(occurred_on: Organization.current_local_date - 1, outcome: "no_answer", paper_reference: "#{@drive.id}-#{@assignment.id}-123456abcdef") }
    assert_response :see_other
    follow_redirect!
    assert_includes response.body, "Caller: Volunteer Helper"
    assert_equal newest, workspace.last_contact(@member)
  end

  test "assignment revocation officer turnover and changed year deny later reads and writes" do
    sign_in_as(@volunteer)
    get membership_person_path(@unassigned), params: { membership_year: @year }
    assert_response :not_found
    get membership_person_path(@member), params: { membership_year: @year - 1 }
    assert_response :forbidden
    @assignment.update!(revoked_at: Time.current)
    get membership_person_path(@member), params: { membership_year: @year }
    assert_response :forbidden
    assert_no_difference "MembershipContact.count" do
      post membership_person_contacts_path(@member), params: { membership_year: @year, membership_contact: contact_attributes }
      assert_response :forbidden
    end
    sign_in_as(@officer)
    get membership_root_path
    assert_response :success
    @office.update!(ends_on: Organization.current_local_date - 1)
    get membership_root_path
    assert_response :forbidden
    assert_not_includes response.body, @member.full_name
  end

  test "officer can transcribe returned revoked assignment sheets while preserving a contact pause" do
    workspace(@volunteer).record_contact!(contact_attributes(outcome: "do_not_contact"))
    @assignment.update!(revoked_at: Time.current)
    sign_in_as(@officer)
    get membership_person_path(@member), params: { membership_year: @year }
    assert_response :success
    assert_select "option[value='#{@assignment.id}']", text: /Revoked \(returned sheet only\)/
    paper = contact_attributes(occurred_on: Organization.current_local_date - 1, outcome: "no_answer",
      paper_reference: "#{@drive.id}-#{@assignment.id}-012345abcdef")
    post membership_person_contacts_path(@member), params: { membership_year: @year, membership_contact: paper }
    assert_response :see_other
    follow_redirect!
    assert_includes response.body, "Caller: Volunteer Helper"
    assert workspace.contact_paused?(@member)
    assert_equal "held", workspace.work_state(@member)
    assert_equal 2, MembershipContact.count
    sign_in_as(@volunteer)
    get membership_person_path(@member), params: { membership_year: @year }
    assert_response :forbidden
  end

  test "volunteer lands in their assigned year when it differs from the next renewal year" do
    @drive.update!(membership_year: @year - 1, purpose: "welcome")
    sign_in_as(@volunteer)
    get membership_root_path
    assert_response :success
    assert_select "input[name='membership_year'][value='#{@year - 1}']"
    get membership_drive_path(@drive)
    assert_response :success
    assert_includes response.body, @member.full_name
    get "/api/membership/workspace", as: :json
    assert_response :success
    assert_equal @year - 1, response.parsed_body["membership_year"]
    get "/api/membership/workspace/drives/#{@drive.id}", as: :json
    assert_response :success
    assert_equal [ @member.id ], response.parsed_body["assignments"].pluck("person_id")
  end

  test "manager assigns members closes a drive and rejects stale updates" do
    sign_in_as(@officer)
    get new_membership_drive_path, params: { membership_year: @year }
    assert_response :success
    post membership_drives_path, params: { membership_year: @year, membership_drive: { title: "Welcome calls", purpose: "welcome", starts_on: Organization.current_local_date, ends_on: Organization.current_local_date + 10 } }
    assert_response :see_other
    drive = MembershipDrive.order(:id).last
    post membership_drive_assignments_path(drive), params: { assignment: { assigned_to_id: @other.id, expires_on: drive.ends_on, person_ids: [ @unassigned.id ] } }
    assert_response :see_other
    follow_redirect!
    assert_includes response.body, "Taylor Member"
    assert_equal @other, drive.assignments.sole.assigned_to
    patch membership_drive_path(drive), params: { lock_version: drive.lock_version }
    assert_response :see_other
    assert_not_nil drive.reload.closed_at
    patch membership_drive_path(drive), params: { lock_version: 0 }
    assert_response :conflict
    sign_in_as(@other)
    get membership_drive_path(drive)
    assert_response :forbidden
  end

  test "invalid callback renders correction form and can then be completed" do
    sign_in_as(@volunteer)
    attributes = contact_attributes(outcome: "callback_requested", notes: "Keep these notes")
    post membership_person_contacts_path(@member), params: { membership_year: @year, membership_contact: attributes }
    assert_response :unprocessable_entity
    assert_includes response.body, "Keep these notes"
    assert_equal 0, MembershipContact.count
    post membership_person_contacts_path(@member), params: { membership_year: @year, membership_contact: attributes.merge(follow_up_on: Organization.current_local_date + 1) }
    assert_response :see_other
    assert_equal "Keep these notes", MembershipContact.sole.notes
  end

  test "a member paid after opening an assignment page is excluded when that form is submitted" do
    sign_in_as(@officer)
    get membership_drive_path(@drive)
    assert_response :success
    assert_includes response.body, @unassigned.full_name
    @unassigned.update!(roster_paid_through_year: @year)
    assert_no_difference "MembershipAssignment.count" do
      post membership_drive_assignments_path(@drive), params: { assignment: { assigned_to_id: @other.id, expires_on: @drive.ends_on, person_ids: [ @unassigned.id ] } }
      assert_response :conflict
    end
    get membership_drive_path(@drive)
    assert_select "input[value='#{@unassigned.id}'][type='checkbox']", count: 0
  end

  test "an invalid optional callback date is preserved for correction instead of silently discarded" do
    sign_in_as(@volunteer)
    post membership_person_contacts_path(@member), params: { membership_year: @year, membership_contact: contact_attributes(follow_up_on: "not-a-date") }
    assert_response :unprocessable_entity
    assert_select "input[name='membership_contact[follow_up_on]'][value='not-a-date']"
    assert_equal 0, MembershipContact.count
  end

  test "PDF source is scoped signed short lived and rechecks authority" do
    @drive.assignments.create!(person: @unassigned, assigned_to: @other, assigned_by: @officer, expires_on: @drive.ends_on)
    @member.update!(roster_address: "Secret mailing address")
    workspace.record_contact!(contact_attributes(notes: "Officer-only notes"))
    token = MembershipPdf.source_token(organization: @organization, user: @volunteer, drive: @drive, caller_id: @other.id)
    get "/internal/membership-pdf-source", params: { token: }
    assert_response :success
    assert_includes response.body, @member.full_name
    assert_not_includes response.body, @unassigned.full_name
    assert_not_includes response.body, "Secret mailing address"
    assert_not_includes response.body, "Officer-only notes"
    assert_not_includes response.body, @member.member_number
    assert_equal "no-store", response.headers["Cache-Control"]
    travel 2.minutes do
      get "/internal/membership-pdf-source", params: { token: }
      assert_response :not_found
    end
    @assignment.update!(revoked_at: Time.current)
    get "/internal/membership-pdf-source", params: { token: }
    assert_response :not_found
    get "/internal/membership-pdf-source", params: { token: "forged" }
    assert_response :not_found
  end

  test "PDF renderer failure keeps saved drive work available" do
    sign_in_as(@officer)
    with_stubbed_class_method(MembershipPdf, :render, ->(**) { raise MembershipPdf::GenerationError, "Renderer unavailable" }) do
      get print_membership_drive_path(@drive)
      assert_response :redirect
      follow_redirect!
      assert_includes response.body, "The call sheet PDF could not be created"
      assert_includes response.body, @member.full_name
    end
    assert_equal 1, @drive.assignments.count
  end
end
