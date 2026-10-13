require "application_system_test_case"
require_relative "../support/buddy_checks_helpers"
require "net/http"

class BuddyCheckCoordinationSystemTest < ApplicationSystemTestCase
  include BuddyChecksHelpers

  setup do
    travel_to Time.zone.local(2026, 11, 15, 12)
    setup_buddy_checks
    @title.update!(name: "1st Vice Commander")
    @officer.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    page.current_window.resize_to(1400, 1000)
  end

  teardown do
    restore_buddy_configuration
    travel_back
    page.current_window.resize_to(1400, 1000)
  end

  test "mobile saved check flows through Post activity member history and the separate county count" do
    system_sign_in(@officer)
    endpoint = URI("#{Capybara.current_session.server.base_url}/api/mobile/v1/buddy-checks")
    ENV["MOBILE_BUDDY_CHECK_ISSUER"] = "#{endpoint.scheme}://#{endpoint.host}:#{endpoint.port}"
    values = buddy_payload(facts: buddy_facts(notes: "Agreed to meet for coffee", occurred_at: "2026-10-20T18:00:00Z"))
    headers = mobile_headers.merge("Content-Type" => "application/json")
    2.times { assert_equal "201", Net::HTTP.post(endpoint, JSON.generate(values), headers).code }
    assert_equal 1, MembershipContact.count
    @organization.membership_contacts.create!(person: @member, recorded_by: @officer, purpose: "renewal", membership_year: @year,
      occurred_on: Organization.current_local_date, channel: "phone", outcome: "reached", notes: "DUES_PRIVATE", submission_key: SecureRandom.uuid)
    visit root_path
    click_button "Menu"
    within ".app-menu-panel" do
      assert_selector ".app-menu-group", text: /YOUR WORK.*Buddy Checks/m
      click_link "Buddy Checks", exact: true
    end
    assert_current_path buddy_checks_activity_path
    assert_selector ".buddy-post-check", text: /Alex Member.*Reached.*Other Helper.*Agreed to meet for coffee/m
    assert_no_text "DUES_PRIVATE"
    capture_layouts("buddy-post-activity")
    click_link "Alex Member", exact: true
    assert_current_path buddy_checks_member_history_path(@member)
    assert_text "Agreed to meet for coffee"
    assert_no_text "DUES_PRIVATE"
    assert_no_text "Dues and reported payments"
    capture_layouts("buddy-member-history")
    click_link "County report", exact: true
    select "October", from: "Month"
    fill_in "Year", with: "2026"
    click_button "Show county total"
    assert_selector ".buddy-county-number strong", text: "1"
    assert_no_text "Agreed to meet for coffee"
    assert_no_text "Alex Member"
    assert_no_text "DUES_PRIVATE"
    capture_layouts("buddy-county-report")
    select "November", from: "Month"
    click_button "Show county total"
    assert_selector ".buddy-county-number strong", text: "0"
  end

  test "phone coordinator records private extra care respects no-contact and preserves the later resolution" do
    system_sign_in(@officer)
    page.current_window.resize_to(390, 844)
    visit buddy_checks_coverage_path
    assert_text "Unknown — no attendance recorded"
    assert_no_text "Absent at the latest two"
    click_link "Alex Member", exact: true
    click_link "Record care follow-up"
    fill_in "Reason and practical next step", with: "Arrange a supportive visit with a trusted Post contact"
    select "Choose a coordinator", from: "Follow-up owner"
    click_button "Save care follow-up"
    assert_text "Assigned to can't be blank"
    assert_field "Reason and practical next step", with: "Arrange a supportive visit with a trusted Post contact"
    select "Officer Helper", from: "Follow-up owner"
    capture_system_screenshot("buddy-care-form-phone")
    click_button "Save care follow-up"
    assert_text "Care follow-up recorded."
    first_review = BuddyCareUpdate.sole
    assert_equal @officer.id, first_review.assigned_to_id
    assert_equal Organization.current_local_date, first_review.follow_up_on
    find("summary", text: "Record a contact preference").click
    fill_in "Preference source", with: "Member asked the Post to pause Buddy Check calls"
    click_button "Save contact preference"
    assert_text "Buddy Check contact preference recorded."
    click_link "Care coverage", exact: true
    within ".buddy-coverage-list" do
      assert_no_text "Alex Member"
      assert_text "Taylor Member"
    end
    select "Extra care follow-up", from: "Show"
    click_button "Review coverage"
    assert_text "Alex Member"
    assert_text "No Buddy Check contact requested"
    assert_text "Arrange a supportive visit"
    capture_layouts("buddy-care-coverage")
    click_link "Alex Member", exact: true
    click_link "Record care follow-up"
    select "Care review complete", from: "Care review"
    fill_in "Reason and practical next step", with: "Care review discussed and settled; contact preference remains paused"
    click_button "Save care follow-up"
    assert_text "Care review complete"
    assert_equal 2, BuddyCareUpdate.count
    assert_equal "Arrange a supportive visit with a trusted Post contact", first_review.reload.notes
    find("summary", text: "Earlier care reviews").click
    assert_text first_review.notes
    @office.update!(ends_on: Organization.current_local_date - 1)
    visit buddy_checks_member_history_path(@member)
    assert_no_text first_review.notes
    assert_text "authorized Post coordinators"
    system_sign_in(@other)
    visit buddy_checks_person_path(@member)
    assert_no_text first_review.notes
    visit buddy_checks_care_path(@member)
    assert_text "authorized Post coordinators"
  end

  test "Buddy Check drives and caller work stay outside renewal lists and dues forms" do
    @drive.update!(purpose: "buddy_check")
    system_sign_in(@officer)
    visit membership_drives_path
    assert_no_link @drive.title
    visit buddy_checks_root_path
    assert_current_path buddy_checks_activity_path
    visit membership_drives_path(purpose: "buddy_check")
    assert_selector "h1", text: "Buddy Check drives"
    assert_no_link "Renewal follow-up"
    assert_no_field "Membership year"
    click_link @drive.title
    click_link "Open caller work"
    assert_text "Buddy Check caller work"
    assert_no_text "Dues and reported payments"
    click_link "Record contact or review", exact: false
    assert_selector "h1", text: "Record Buddy Check result"
    select "Reached", from: "What happened?"
    fill_in "Brief notes", with: "Returned Buddy Check sheet confirms a friendly visit"
    click_button "Record Buddy Check result"
    assert_current_path buddy_checks_member_history_path(@member)
    assert_text "Returned Buddy Check sheet confirms a friendly visit"
    assert_equal "buddy_check", MembershipContact.sole.purpose
    capture_layouts("buddy-drive-history")
  end

  private

  def capture_layouts(name)
    [ [ 1400, 1000 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth"), "No horizontal overflow"
      assert page.evaluate_script(<<~JS), "Readable Buddy Check targets"
        [...document.querySelectorAll('.task-workspace button, .task-workspace input:not([type=hidden]), .task-workspace select, .task-link')]
          .filter(element => element.getClientRects().length)
          .every(element => element.getBoundingClientRect().height >= 44 && parseFloat(getComputedStyle(element).fontSize) >= 16)
      JS
      capture_system_screenshot("#{name}-#{width}")
    end
  end
end
