require "application_system_test_case"
require "base64"
require "open3"

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
    capture_system_screenshot("minutes-attested-desktop")

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
    capture_system_screenshot("minutes-corrections-mobile")

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
    capture_system_screenshot("minutes-approved-mobile")
    visit admin_meeting_path(@meeting)
    assert_selector ".minutes-status-card h2", text: "Approved and locked"
    assert_no_link "Record meeting approval"
    @adjutant.permission_grants.create!(capability: "manage_agendas")
    original_meeting = @meeting.reload.attributes
    revision = @minutes.member_revision
    original_revision = revision.attributes
    member = officer("Member")
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      system_sign_in(@adjutant)
      visit edit_admin_meeting_path(@meeting)
      fill_in "Meeting title (optional)", with: "Rewritten after final approval"
      click_button "Save meeting"
      assert_selector ".error-summary", text: "locked because its minutes are approved"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      capture_system_screenshot("final-meeting-refusal-#{width}")
      assert_equal original_meeting, @meeting.reload.attributes
      assert_equal original_revision, revision.reload.attributes
      click_link "Cancel", exact: true
      assert_current_path admin_meeting_path(@meeting)

      system_sign_in(member)
      visit meetings_path
      within find("a[href='#{meeting_minutes_path(@meeting)}']").ancestor(".member-meeting-row") do
        click_link "View minutes"
      end
      assert_current_path meeting_minutes_path(@meeting)
      assert_selector ".agenda-meeting-heading h1", text: "Corrected PEC Meeting"
      assert_selector ".member-minutes-status", text: "Approved as corrected"
      assert_no_text "Rewritten after final approval"
      assert_final_pdf
      assert_equal original_meeting, @meeting.reload.attributes
      assert_equal original_revision, revision.reload.attributes
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  test "Adjutant draft attests directly with one clear status on desktop and phone" do
    system_sign_in(@adjutant)
    visit admin_meeting_minutes_path(@meeting)
    assert_selector ".minutes-status-card h2", text: "Draft", exact_text: true
    assert_no_button "Send to Adjutant"
    capture_system_screenshot("minutes-draft-desktop")
    page.current_window.resize_to(390, 844)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    capture_system_screenshot("minutes-draft-mobile")
    click_button "Attest and share with members"
    confirm_by_email(via_link: true)
    assert_selector ".minutes-status-card h2", text: "Attested — awaiting meeting approval"
    assert_equal 1, @minutes.reload.revisions.count
    assert_nil @minutes.current_revision.approved_by_id
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  private

  def assert_final_pdf
    previous_port = ENV["PDF_RENDER_PORT"]
    ENV["PDF_RENDER_PORT"] = URI.parse(page.current_url).port.to_s
    encoded = page.evaluate_async_script(<<~JS, print_meeting_minutes_path(@meeting))
      const [url, done] = arguments;
      fetch(url).then(response => {
        if (!response.ok || !response.headers.get('content-type').includes('application/pdf')) throw new Error('Expected a readable minutes PDF');
        return response.blob();
      }).then(blob => {
        const reader = new FileReader();
        reader.onload = () => done(reader.result.split(',')[1]);
        reader.readAsDataURL(blob);
      }).catch(error => done({error: error.message}));
    JS
    assert_kind_of String, encoded
    text, stderr, status = Open3.capture3("pdftotext", "-", "-", stdin_data: Base64.decode64(encoded), binmode: true)
    assert status.success?, stderr
    assert_includes text, "Corrected PEC Meeting"
    assert_includes text, "Approved as corrected"
    assert_not_includes text, "Rewritten after final approval"
  ensure
    ENV["PDF_RENDER_PORT"] = previous_port
  end

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
    capture_system_screenshot("minutes-confirmation-#{width}")
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
