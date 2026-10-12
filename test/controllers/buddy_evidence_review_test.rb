require "test_helper"
require_relative "../support/buddy_checks_helpers"

class BuddyEvidenceReviewTest < ActionDispatch::IntegrationTest
  include BuddyChecksHelpers
  setup { setup_buddy_checks }
  teardown { restore_buddy_configuration }

  test "membership managers without the pilot see no mobile site controls and cannot open their URLs" do
    @officer.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    @officer.permission_grants.create!(capability: "manage_settings")
    sign_in_as(@officer)
    get profile_path
    assert_response 200
    assert_select "a[href='#{mobile_sessions_path}']", count: 0
    get membership_root_path
    assert_response 200
    assert_select "a[href='#{membership_buddy_attendances_path}']", count: 0
    get membership_person_path(@member)
    assert_response 200
    assert_select "a[href='#{membership_buddy_address_path(@member)}']", count: 0
    [ mobile_sessions_path, membership_buddy_attendances_path, membership_buddy_address_path(@member) ].each do |path|
      get path
      assert_response :forbidden
    end
    post membership_buddy_attendance_path(buddy_meeting), params: { expected_revision: 0 }
    assert_response :forbidden
    post membership_buddy_address_path(@member), params: { source_note: "Denied" }
    assert_response :forbidden
    assert_equal 0, BuddyAttendanceRegister.count
    assert_equal 0, BuddyAddressReview.count
    assert @officer.can?("manage_settings")
    assert @officer.full_membership_access?
  end

  test "incomplete attendance cannot be confirmed and a later officer authority change denies saving" do
    meeting = buddy_meeting
    sign_in_as(@officer)
    entries = { @member.id.to_s => "absent", @unassigned.id.to_s => "not_recorded" }
    post membership_buddy_attendance_path(meeting), params: { expected_revision: 0, entries:, complete: "1", coverage_note: "Checked synthetic list." }
    assert_response :unprocessable_entity
    assert_equal 0, BuddyAttendanceRegister.count
    assert_select ".app-flash-alert", text: /cannot include not-recorded/
    assert_select "select[name='entries[#{@member.id}]'] option[selected][value='absent']"
    assert_select "textarea[name='coverage_note']", text: "Checked synthetic list."
    post membership_buddy_attendance_path(meeting), params: { expected_revision: 0, entries:, complete: "0", coverage_note: "Checked synthetic list." }
    assert_response :redirect
    assert_not BuddyAttendanceRegister.sole.complete?
    @office.update!(ends_on: Organization.current_local_date - 1)
    post membership_buddy_attendance_path(meeting), params: { expected_revision: 1, entries:, complete: "0", coverage_note: "Stale officer." }
    assert_response :forbidden
    assert_equal 1, BuddyAttendanceRegister.count
  end

  test "address review rejects a source changed since opening and officer turnover removes address export" do
    @officer.permission_grants.create!(capability: "export_buddy_contacts")
    sign_in_as(@officer)
    digest = BuddyAddressReview.source_digest(@member)
    @member.update!(roster_address: "Changed source")
    post membership_buddy_address_path(@member), params: { source_digest: digest, components: { city: "Example" }, source_note: "Old source." }
    assert_response :conflict
    assert_equal 0, BuddyAddressReview.count
    post membership_buddy_address_path(@member), params: { source_digest: BuddyAddressReview.source_digest(@member), components: { city: "Example" }, source_note: "Reviewed current source." }
    assert_response :redirect
    headers = mobile_headers(@officer)
    get "/api/mobile/v1/people/#{@member.id}/contact-export", headers: headers
    assert_equal "Example", response.parsed_body.dig("fields", "address", "city")
    @office.update!(ends_on: Organization.current_local_date - 1)
    get "/api/mobile/v1/people/#{@member.id}/contact-export", headers: headers
    assert_response :success
    assert_equal({}, response.parsed_body.dig("fields", "address"))
  end
end
