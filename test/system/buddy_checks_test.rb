require "application_system_test_case"
require_relative "../support/buddy_checks_helpers"

class BuddyChecksSystemTest < ApplicationSystemTestCase
  include BuddyChecksHelpers
  setup do
    setup_buddy_checks
    @meeting = buddy_meeting
    page.current_window.resize_to(1400, 1000)
  end
  teardown do
    restore_buddy_configuration
    page.current_window.resize_to(1400, 1000)
  end

  test "officer reviews explicit attendance and address provenance at desktop and phone widths" do
    system_sign_in(@officer)
    visit membership_root_path
    click_link "General-member attendance"
    click_link "Review attendance"
    assert_text "This register covers 2 named members"
    fill_in "How was this general-member list checked?", with: "Synthetic general-member sign-in sheet reviewed with the roster."
    select "Absent", from: "Alex Member"
    select "Present", from: "Taylor Member"
    capture_system_screenshot("buddy-attendance-desktop")
    assert_no_horizontal_overflow
    page.current_window.resize_to(390, 844)
    capture_system_screenshot("buddy-attendance-phone")
    assert_no_horizontal_overflow
    check "I reviewed attendance for every member listed"
    click_button "Save attendance revision"
    assert_text "General-member attendance saved. Minutes are unchanged."
    assert_selector "input[name='expected_revision'][value='1']", visible: :all
    assert BuddyAttendanceRegister.sole.complete?
    assert_equal "absent", BuddyAttendanceRegister.sole.entries.fetch(@member.id.to_s)
    uncheck "I reviewed attendance for every member listed"
    select "Not recorded", from: "Alex Member"
    click_button "Save attendance revision"
    assert_text "General-member attendance saved"
    # The first save's identical notice can still be visible while this POST runs.
    assert_selector "input[name='expected_revision'][value='2']", visible: :all
    assert_equal 2, BuddyAttendanceRegister.count
    assert_not BuddyAttendanceRegister.latest.sole.complete?
    assert_equal 0, MeetingMinutes.count
    visit membership_buddy_address_path(@member)
    fill_in "Street", with: "12 Example Way"
    fill_in "Source checked", with: "Synthetic mailing label explicitly reviewed."
    capture_system_screenshot("buddy-address-phone")
    click_button "Save reviewed address"
    assert_text "Reviewed address components saved."
    assert_equal({ "street" => "12 Example Way" }, BuddyAddressReview.sole.components)
    assert_nil @member.reload.roster_address
    page.current_window.resize_to(1400, 1000)
    capture_system_screenshot("buddy-address-desktop")
    assert_no_horizontal_overflow
  end

  test "human consent and per-session revocation remain legible on narrow screens" do
    system_sign_in(@other)
    ENV["MOBILE_BUDDY_CHECK_ISSUER"] = URI.parse(page.current_url).then { |uri| "#{uri.scheme}://#{uri.host}:#{uri.port}" }
    verifier = SecureRandom.urlsafe_base64(48)
    query = { client_id: @mobile_client.uid, redirect_uri: @mobile_client.redirect_uri, response_type: "code", scope: "buddy_check",
      state: SecureRandom.hex(32), code_challenge_method: "S256", code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }
    visit "/oauth/authorize?#{query.to_query}"
    assert_button "Connect Buddy Checks"
    capture_system_screenshot("buddy-consent-desktop")
    page.current_window.resize_to(390, 844)
    assert_no_horizontal_overflow
    capture_system_screenshot("buddy-consent-phone")
    mobile_headers
    visit mobile_sessions_path
    assert_button "Revoke session #{@mobile_tokens[@other.id].id}"
    capture_system_screenshot("buddy-sessions-phone")
    click_button "Revoke session #{@mobile_tokens[@other.id].id}"
    assert_text "No active mobile sessions."
    assert @mobile_tokens[@other.id].reload.revoked_at
  end

  test "browser submits explicit consent with its own origin and an origin-only referrer" do
    previous = ActionController::Base.allow_forgery_protection
    previous_origin_check = ActionController::Base.forgery_protection_origin_check
    ActionController::Base.allow_forgery_protection = true
    ActionController::Base.forgery_protection_origin_check = true
    system_sign_in(@other)
    issuer = URI.parse(page.current_url).then { |uri| "#{uri.scheme}://#{uri.host}:#{uri.port}" }
    ENV["MOBILE_BUDDY_CHECK_ISSUER"] = issuer
    verifier = SecureRandom.urlsafe_base64(48)
    query = { client_id: @mobile_client.uid, redirect_uri: @mobile_client.redirect_uri, response_type: "code", scope: "buddy_check",
      state: SecureRandom.hex(32), code_challenge_method: "S256", code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }
    visit "/oauth/authorize?#{query.to_query}"
    assert_button "Connect Buddy Checks"
    assert_equal 0, Doorkeeper::AccessGrant.count

    submissions = Queue.new
    observer = ->(event) do
      payload = event.payload
      if payload[:controller] == "Mobile::AuthorizationsController" && payload[:action] == "create"
        submissions << { origin: payload[:request].origin, referrer: payload[:request].referer,
          status: payload[:status], location: payload[:response]&.location }
      end
    end
    # Observe the server request; do not inject headers or replace the browser form.
    ActiveSupport::Notifications.subscribed(observer, "process_action.action_controller") do
      click_button "Connect Buddy Checks"
      submission = submissions.pop(timeout: 10)
      assert submission, "The browser did not submit consent"
      assert_equal issuer, submission[:origin]
      assert_equal "#{issuer}/", submission[:referrer]
      assert_equal 302, submission[:status]
      callback = URI.parse(submission.fetch(:location))
      returned = URI.decode_www_form(callback.query).to_h
      callback.query = nil
      assert_equal @mobile_client.redirect_uri, callback.to_s
      assert_equal query[:state], returned["state"]
      assert returned["code"].present?
    end
    grant = Doorkeeper::AccessGrant.sole
    assert_equal @other.id, grant.resource_owner_id
    assert_equal @mobile_client.id, grant.application_id
    assert_equal "S256", grant.code_challenge_method
    assert_equal query[:code_challenge], grant.code_challenge
    assert_equal 0, Doorkeeper::AccessToken.count
    # Chromium has no native callback handler; finish that navigation before reuse.
    visit mobile_sessions_path
    assert_text "No active mobile sessions."
  ensure
    ActionController::Base.allow_forgery_protection = previous
    ActionController::Base.forgery_protection_origin_check = previous_origin_check
  end

  test "administrator grants and removes Contacts export without giving membership access" do
    @officer.permission_grants.create!(capability: "manage_settings")
    system_sign_in(@officer)
    headers = mobile_headers(@other)
    api = ActionDispatch::Integration::Session.new(Rails.application)
    path = "/api/mobile/v1/people/#{@member.id}/contact-export"
    api.get(path, headers:)
    assert_equal 403, api.response.status
    visit person_path(@other.person)
    check "Copy permitted Buddy Check contacts to personal Contacts"
    find("body").scroll_to(find("input[value='export_buddy_contacts']"), align: :center)
    capture_system_screenshot("buddy-export-permission-desktop")
    assert_no_horizontal_overflow
    page.current_window.resize_to(390, 844)
    find("body").scroll_to(find("input[value='export_buddy_contacts']"), align: :center)
    capture_system_screenshot("buddy-export-permission-phone")
    assert_no_horizontal_overflow
    click_button "Save permissions"
    assert_text "Permissions updated."
    assert_selector "input[value='export_buddy_contacts'][checked]"
    assert_equal %w[export_buddy_contacts use_mobile_buddy_checks], @other.permission_grants.order(:capability).pluck(:capability)
    assert_not @other.full_membership_access?
    api.get(path, headers:)
    assert_equal 200, api.response.status
    uncheck "Copy permitted Buddy Check contacts to personal Contacts"
    click_button "Save permissions"
    assert_text "Permissions updated."
    # Wait for the server-rendered grant, rather than the locally toggled checkbox.
    assert_selector "input[value='export_buddy_contacts']:not([checked])"
    api.get(path, headers:)
    assert_equal 403, api.response.status
    assert_equal "export_not_permitted", api.response.parsed_body.dig("error", "code")
  end

  test "pilot removal hides phone controls for a membership manager at desktop and narrow widths" do
    system_sign_in(@officer)
    visit profile_path
    assert_link "Mobile sessions"
    @officer.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    [ [ 1400, 1000 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit profile_path
      assert_no_link "Mobile sessions"
      visit membership_root_path
      assert_link "Drives"
      assert_no_link "General-member attendance"
      visit membership_person_path(@member)
      assert_no_link "Review mailing address"
      assert_no_horizontal_overflow
      capture_system_screenshot("buddy-nonpilot-#{width}")
    end
  end

  private

  def assert_no_horizontal_overflow
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    sizes = page.evaluate_script("Array.from(document.querySelectorAll('main input:not([type=hidden]), main select, main button, main textarea')).map(e => parseFloat(getComputedStyle(e).fontSize))")
    assert sizes.all? { |size| size >= 16 }, sizes.inspect
  end
end
