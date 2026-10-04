require "application_system_test_case"

class MinutesApprovalFlowTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    page.current_window.resize_to(1400, 1000)
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "PEC", slug: "pec")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.month.ago, title: "PEC Meeting")
    @approving_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago, title: "Later PEC Meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @commander = officer("Commander", "manage_minutes", "approve_minutes", "record_minutes_approval")
    @adjutant = officer("Adjutant", "manage_minutes", "attest_minutes", "record_minutes_approval")
  end

  test "Commander handoff Adjutant edits and meeting corrections reach a locked record without extra approval clicks" do
    system_sign_in(@commander)
    visit admin_meeting_path(@meeting)
    assert_selector ".minutes-status-card h2", text: "Draft", exact_text: true
    click_button "Send to Adjutant"
    confirm_by_email
    assert_current_path admin_meeting_minutes_path(@meeting)
    assert_selector ".minutes-status-card h2", text: "Ready for Adjutant review"
    assert_predicate @minutes.reload, :approved?

    system_sign_in(@adjutant)
    visit admin_meeting_minutes_path(@meeting)
    click_link "Edit heading"
    fill_in "Document title", with: "Reviewed PEC Meeting"
    click_button "Save heading"
    assert_selector ".minutes-status-card h2", text: "Ready for Adjutant review"
    assert_no_button "Send to Adjutant"
    click_button "Attest and share with members"
    confirm_by_email
    assert_selector ".minutes-status-card h2", text: "Attested — awaiting meeting approval"
    assert_predicate @minutes.reload, :member_visible?
    assert_nil @minutes.current_revision.approved_by_id
    page.save_screenshot("/tmp/minutes-attested-desktop.png")

    click_link "Record meeting approval"
    select "PEC — #{legion_date_for_test(@approving_meeting.starts_at)}", from: "Meeting where these minutes were approved"
    choose "Approved with corrections"
    fill_in "Corrections or procedure note", with: "Correct the record title to Corrected PEC Meeting."
    click_button "Record meeting approval"
    confirm_by_email
    assert_selector ".minutes-status-card h2", text: "Corrections to finish"
    assert_nil @minutes.reload.membership_approval
    assert_equal "Reviewed PEC Meeting", @minutes.member_revision.payload.fetch("title")
    page.current_window.resize_to(390, 844)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    assert_equal 1, page.evaluate_script("getComputedStyle(document.querySelector('.minutes-progress')).gridTemplateColumns.split(' ').length")
    page.save_screenshot("/tmp/minutes-corrections-mobile.png")

    click_link "Edit heading"
    fill_in "Document title", with: "Corrected PEC Meeting"
    click_button "Save heading"
    click_button "Confirm corrections and lock minutes"
    confirm_by_email
    assert_selector ".minutes-status-card h2", text: "Approved and locked"
    assert_no_link "Edit heading"
    assert_no_link "Correct this copy"
    assert_predicate @minutes.reload, :membership_approved?
    assert_equal @approving_meeting, @minutes.membership_approval.approving_meeting
    assert_equal "Corrected PEC Meeting", @minutes.member_revision.payload.fetch("title")
    page.save_screenshot("/tmp/minutes-approved-mobile.png")
    visit admin_meeting_path(@meeting)
    assert_selector ".minutes-status-card h2", text: "Approved and locked"
    assert_no_link "Record meeting approval"
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  test "Adjutant draft attests directly with one clear status on desktop and phone" do
    system_sign_in(@adjutant)
    visit admin_meeting_minutes_path(@meeting)
    assert_selector ".minutes-status-card h2", text: "Draft", exact_text: true
    assert_no_button "Send to Adjutant"
    page.save_screenshot("/tmp/minutes-draft-desktop.png")
    page.current_window.resize_to(390, 844)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot("/tmp/minutes-draft-mobile.png")
    click_button "Attest and share with members"
    confirm_by_email(via_link: true)
    assert_selector ".minutes-status-card h2", text: "Attested — awaiting meeting approval"
    assert_equal 1, @minutes.reload.revisions.count
    assert_nil @minutes.current_revision.approved_by_id
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  private

  def confirm_by_email(via_link: false)
    assert_selector "h1", text: "Confirm and complete"
    perform_enqueued_jobs do
      click_button "Email me a code and link"
      assert_field "8-digit confirmation code"
    end
    email_body = ActionMailer::Base.deliveries.last.text_part.body.to_s
    if via_link
      url = email_body[/https?:\/\/\S+/]
      assert url
      visit URI.parse(url).request_uri
      assert_selector "h2", text: "Attest and share with members"
      assert_predicate @minutes.reload, :draft?
    else
      code = email_body[/\b\d{4} \d{4}\b/]
      assert code
      fill_in "8-digit confirmation code", with: code
    end
    width = page.evaluate_script("window.innerWidth") > 560 ? "desktop" : "mobile"
    page.save_screenshot("/tmp/minutes-confirmation-#{width}.png")
    click_button "Confirm and complete"
    assert_current_path admin_meeting_minutes_path(@meeting)
  end

  def officer(name, *capabilities)
    user = User.create!(person: Person.create!(first_name: "Test", last_name: name), email_address: "#{name.downcase}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| user.permission_grants.create!(capability:) }
    user
  end

  def legion_date_for_test(value)
    value.to_date.strftime("%d %b %Y").upcase
  end
end
