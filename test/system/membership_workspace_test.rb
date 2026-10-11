require "application_system_test_case"
require_relative "../support/membership_workspace_helpers"
require "net/http"
require "open3"

class MembershipWorkspaceSystemTest < ApplicationSystemTestCase
  include MembershipWorkspaceHelpers

  setup do
    setup_membership_workspace
    page.current_window.resize_to(1400, 1000)
  end

  teardown { page.current_window.resize_to(1400, 1000) }

  test "officer tracks receipt saves summary and starts a drive at desktop and phone widths" do
    system_sign_in(@officer)
    visit membership_root_path(membership_year: @year)
    assert_selector ".sec-head-label", text: "NEEDS ATTENTION"
    capture_system_screenshot("membership-officer-desktop")
    assert_readable_membership_page
    click_link "Alex Member"
    assert_current_path membership_person_path(@member, membership_year: @year)
    assert_no_selector "html[data-turbo-preview]", visible: :all
    within "form[action='#{membership_dues_records_path}']" do
      fill_in "Amount received ($)", with: "45.00"
      find_field("Receipt or check reference").click
      fill_in "Receipt or check reference", with: "Synthetic receipt 1"
      assert_field "Amount received ($)", with: "45.00"
      click_button "Record membership entry"
    end
    assert_text "Post received dues; confirm with National"
    assert_equal @year - 1, @member.reload.roster_paid_through_year
    assert_equal 45.to_d, @member.membership_dues_records.sole.amount
    capture_system_screenshot("membership-member-desktop")
    page.current_window.resize_to(390, 844)
    assert_readable_membership_page
    capture_system_screenshot("membership-member-phone")
    click_link "Membership worklist"
    click_link "Adjutant report", exact: true
    assert_text "We received their dues, but National's roster has not confirmed"
    assert_readable_membership_page
    capture_system_screenshot("membership-report-phone")
    click_button "Save today's Adjutant summary"
    assert_text "Adjutant membership summary"
    assert_equal "45.0", MembershipSummary.sole.payload["post_dues_received"]
    visit membership_root_path(membership_year: @year)
    assert_readable_membership_page
    capture_system_screenshot("membership-officer-phone")
    click_link "Drives", exact: true
    click_link "Create membership drive"
    fill_in "Drive name", with: "New member welcome"
    select "New member welcome", from: "Purpose"
    click_button "Create drive"
    assert_text "New member welcome"
    select "Other Helper", from: "Caller"
    check "Taylor Member"
    click_button "Assign selected members"
    assert_text "Caller: Other Helper"
    drive = MembershipDrive.order(:id).last
    assert_equal @other, drive.assignments.sole.assigned_to
    assert_readable_membership_page
    capture_system_screenshot("membership-drive-phone")
  end

  test "worklist defaults to action and the menu stays hidden for an ordinary member" do
    @unassigned.update!(roster_paid_through_year: @year)
    callback = membership_person("Callback", 3)
    online = membership_person("Online", 4)
    received = membership_person("Received", 5)
    review = membership_person("Review", 6)
    review.update!(roster_paid_through_year: nil)
    deceased = membership_person("Deceased", 7)
    deceased.update!(roster_member_status: "Deceased")
    removed = membership_person("Removed", 8)
    removed.update!(roster_removed_at: Time.current)
    workspace.record_contact!(contact_attributes(person_id: callback.id, membership_assignment_id: nil,
      outcome: "callback_requested", follow_up_on: Organization.current_local_date))
    workspace.record_dues!(dues_attributes(person_id: online.id, kind: "national_reported", amount: nil))
    workspace.record_dues!(dues_attributes(person_id: received.id))
    system_sign_in(@officer)
    visit membership_root_path
    assert_link "Alex Member"
    assert_no_link "Taylor Member"
    assert_no_link deceased.roster_display_name
    assert_no_link removed.roster_display_name
    assert_no_text "Money recorded for this year"
    assert_no_button "Record Post-share check"
    assert_readable_membership_page
    capture_system_screenshot("membership-worklist-desktop")
    page.current_window.resize_to(390, 844)
    assert_readable_membership_page
    capture_system_screenshot("membership-worklist-phone")
    page.current_window.resize_to(1400, 1000)
    select "All members", from: "Show", exact: true
    click_button "Show members"
    assert_link "Taylor Member"
    assert_text "No renewal follow-up needed"
    click_link deceased.roster_display_name
    assert_current_path membership_person_path(deceased, membership_year: @year)
    assert_selector ".page-title", text: deceased.roster_display_name
    assert_no_selector "html[data-turbo-preview]", visible: :all
    assert_text "Deceased in National roster; no outreach"
    assert_no_selector "a[href^='tel:'], a[href^='mailto:']"
    assert_readable_membership_page
    capture_system_screenshot("membership-deceased-desktop")
    page.current_window.resize_to(390, 844)
    assert_readable_membership_page
    capture_system_screenshot("membership-deceased-phone")
    find("summary", text: "Add a review or returned paper result").click
    select "Officer review of a recorded result", from: "Channel"
    select "Officer review needed", from: "What happened?"
    fill_in "Brief notes", with: "Reviewed retained history"
    click_button "Record contact"
    assert_text "Review recorded"
    assert_text "Reviewed retained history"
    assert_equal "administrative_review", deceased.membership_contacts.sole.channel
    click_link "Membership worklist"
    assert_no_link deceased.roster_display_name
    page.current_window.resize_to(1400, 1000)
    click_link "Adjutant report", exact: true
    assert_text "Paid for #{@year}"
    capture_system_screenshot("membership-report-desktop")
    assert_readable_membership_page
    click_link "Post checks", exact: true
    fill_in "Amount received ($)", with: "130.25"
    fill_in "Receipt or check reference", with: "Synthetic National check"
    click_button "Record Post-share check"
    assert_text "$130.25"
    assert_current_path membership_post_checks_path(membership_year: @year)
    assert_equal @year - 1, @member.reload.roster_paid_through_year
    capture_system_screenshot("membership-checks-desktop")
    assert_readable_membership_page

    system_sign_in(@other)
    visit root_path
    assert_no_link "Membership", exact: true
    page.current_window.resize_to(390, 844)
    click_button "Menu"
    assert_no_link "Membership", exact: true
    visit membership_root_path
    assert_text "You do not have a current membership assignment"
  end

  test "assigned caller corrects validation and records callback on a phone" do
    system_sign_in(@volunteer)
    page.current_window.resize_to(390, 844)
    visit membership_root_path(membership_year: @year)
    assert_link "Alex Member"
    assert_no_link "Taylor Member"
    click_link "Alex Member"
    select "Callback requested", from: "What happened?"
    fill_in "Brief notes", with: "Call after lunch on the agreed day"
    click_button "Record contact"
    assert_text "Follow up on can't be blank"
    fill_in "Follow-up date (if needed)", with: (Organization.current_local_date + 3).strftime("%d %b %Y").upcase
    click_button "Record contact"
    assert_text "Contact recorded"
    assert_text "Call after lunch on the agreed day"
    assert_equal @volunteer, MembershipContact.sole.recorded_by
    assert_equal Organization.current_local_date + 3, MembershipContact.sole.follow_up_on
    assert_readable_membership_page
    capture_system_screenshot("membership-caller-phone")
    visit membership_person_path(@member, membership_year: @year)
    assert_text "Call after lunch on the agreed day"
    @assignment.update!(revoked_at: Time.current)
    visit membership_person_path(@member, membership_year: @year)
    assert_text "You do not have a current membership assignment"
    assert_no_text "Call after lunch on the agreed day"
  end

  test "actual call sheet and saved summary PDFs contain permitted data and complete member blocks" do
    @unassigned.update!(first_name: "Alexandria-Catherine", last_name: "Long Member Name for Calling Team", roster_phone_number: nil, roster_email_address: nil)
    @drive.assignments.create!(person: @unassigned, assigned_to: @other, assigned_by: @officer, expires_on: @drive.ends_on)
    5.times do |index|
      person = membership_person("Print#{index}", index + 3)
      @drive.assignments.create!(person:, assigned_to: @volunteer, assigned_by: @officer, expires_on: @drive.ends_on)
    end
    deceased = membership_person("DeceasedPrint", 9)
    renewed = membership_person("RenewedPrint", 10)
    [ deceased, renewed ].each do |person|
      @drive.assignments.create!(person:, assigned_to: @volunteer, assigned_by: @officer, expires_on: @drive.ends_on)
    end
    deceased.update!(roster_member_status: "Deceased")
    renewed.update!(roster_paid_through_year: @year)
    @member.update!(roster_address: "Do not print private mailing address")
    workspace.record_contact!(contact_attributes(notes: "Do not print officer notes"))
    system_sign_in(@officer)
    visit membership_drive_path(@drive)
    pdf = delivered_pdf(print_membership_drive_path(@drive))
    text, pages = pdf_text_and_pages(pdf, "membership-call-sheets")
    assert_operator pages, :>=, 3
    assert_includes text, "Not recorded"
    assert_includes text, @member.full_name
    assert_includes text, @unassigned.full_name
    assert_not_includes text, "Do not print"
    assert_not_includes text, @member.member_number
    assert_not_includes text, deceased.full_name
    assert_not_includes text, renewed.full_name
    assert_equal @drive.assignments.count - 2, text.scan("Notes:").size
    assert_complete_pdf_blocks(pdf)
    snapshot = workspace.save_summary!(submission_key: "print-summary")
    summary_text, = pdf_text_and_pages(delivered_pdf(print_membership_summary_path(snapshot)), "membership-adjutant-summary")
    assert_includes summary_text, "Adjutant membership summary"
    assert_includes summary_text, "Deceased or removed records"
    assert_not_includes summary_text, @member.full_name

    system_sign_in(@volunteer)
    visit membership_drive_path(@drive)
    caller_text, = pdf_text_and_pages(delivered_pdf(print_membership_drive_path(@drive, caller_id: @other.id)), "membership-caller-sheets")
    assert_includes caller_text, @member.full_name
    assert_not_includes caller_text, @unassigned.full_name
  end

  test "returned same day sheet preserves callback until an officer records a reasoned review" do
    system_sign_in(@volunteer)
    visit membership_person_path(@member, membership_year: @year)
    select "Callback requested", from: "What happened?"
    fill_in "Follow-up date (if needed)", with: (Organization.current_local_date + 3).strftime("%d %b %Y").upcase
    fill_in "Brief notes", with: "Agreed callback after lunch"
    click_button "Record contact"
    assert_text "Contact recorded"
    callback = MembershipContact.sole

    system_sign_in(@officer)
    visit membership_person_path(@member, membership_year: @year)
    find("#membership_contact_membership_assignment_id").find("option[value='#{@assignment.id}']").select_option
    select "No answer", from: "What happened?"
    fill_in "Paper reference (when entering a call sheet)", with: "#{@drive.id}-#{@assignment.id}-123456abcdef"
    click_button "Record contact"
    assert_text "Contact recorded"
    assert_equal callback, workspace.last_contact(@member)

    system_sign_in(@volunteer)
    page.current_window.resize_to(390, 844)
    visit membership_person_path(@member, membership_year: @year)
    assert_text "No answer"
    assert_text "Agreed callback after lunch"
    assert_equal callback, workspace(@volunteer).last_contact(@member)
    assert_readable_membership_page

    system_sign_in(@officer)
    visit membership_person_path(@member, membership_year: @year)
    find("#membership_contact_membership_assignment_id").find("option[value='#{@assignment.id}']").select_option
    select "Officer review of a recorded result", from: "Channel"
    select "Callback requested", from: "What happened?"
    fill_in "Follow-up date (if needed)", with: (Organization.current_local_date + 5).strftime("%d %b %Y").upcase
    fill_in "Brief notes", with: "Caller confirmed the later date after reviewing the sheet"
    click_button "Record contact"
    assert_text "Review recorded"
    assert_equal Organization.current_local_date + 5, workspace.last_contact(@member).follow_up_on
    assert_equal 3, MembershipContact.count
    assert_equal @year - 1, @member.reload.roster_paid_through_year
  end

  test "Buddy Check purpose shows care outcomes and prevents renewal solicitation" do
    @drive.update!(purpose: "buddy_check")
    @member.update!(roster_paid_through_year: @year)
    system_sign_in(@volunteer)
    visit membership_root_path(membership_year: @year)
    click_link "Alex Member"
    assert_current_path membership_person_path(@member, membership_year: @year, assignment_id: @assignment.id)
    within "#membership_contact_outcome" do
      assert_no_selector "option[value='wants_to_renew']:not([disabled])", visible: :all
      assert_selector "option[value='reached']:not([disabled])", visible: :all
    end
    select "Reached", from: "What happened?"
    fill_in "Brief notes", with: "Welcomed a visit from the Post"
    click_button "Record contact"
    assert_text "Contact recorded"
    assert_equal "buddy_check", MembershipContact.sole.purpose
    assert_empty @member.membership_dues_records
  end

  private

  def assert_readable_membership_page
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth + 1"), "The page must fit the viewport"
    assert_operator find(".page-title").style("font-size")["font-size"].to_f, :>=, 24
    page.all(".membership-work-lines p, .membership-form .f, .membership-task-action p, .membership-task-date, .membership-navigation a").each do |element|
      assert_operator element.style("font-size")["font-size"].to_f, :>=, 16
    end
  end

  def delivered_pdf(path)
    uri = URI.join(page.current_url, path)
    cookie = page.driver.browser.manage.all_cookies.map { |item| "#{item[:name]}=#{item[:value]}" }.join("; ")
    original_port = ENV["PDF_RENDER_PORT"]
    ENV["PDF_RENDER_PORT"] = uri.port.to_s
    result = Net::HTTP.start(uri.host, uri.port) { |http| http.get(uri.request_uri, { "Cookie" => cookie }) }
    assert_equal "200", result.code
    assert_equal "application/pdf", result["Content-Type"]
    assert_includes result["Cache-Control"], "no-store"
    assert result.body.start_with?("%PDF")
    result.body
  ensure
    ENV["PDF_RENDER_PORT"] = original_port
  end

  def pdf_text_and_pages(pdf, name)
    directory = ENV.fetch("SYSTEM_TEST_CAPTURE_DIR", Rails.root.join("tmp", "membership-qa").to_s)
    FileUtils.mkdir_p(directory)
    path = File.join(directory, "#{name}.pdf")
    File.binwrite(path, pdf)
    text, status = Open3.capture2("pdftotext", "-layout", path, "-")
    assert status.success?
    [ text, text.count("\f") ]
  end

  def assert_complete_pdf_blocks(pdf)
    Tempfile.create([ "membership-geometry", ".pdf" ]) do |file|
      file.binmode
      file.write(pdf)
      file.flush
      xml, status = Open3.capture2("pdftotext", "-bbox-layout", file.path, "-")
      assert status.success?
      document = Nokogiri::XML(xml).remove_namespaces!
      document.css("page").each do |sheet|
        words = sheet.css("word").map(&:text)
        assert_equal words.count("Reference:"), words.count("Notes:"), "Every member block must end on the same page where it starts"
        assert_in_delta 612, sheet["width"].to_f, 1
        assert_in_delta 792, sheet["height"].to_f, 1
        sheet.css("word").each do |word|
          assert_operator word["xMin"].to_f, :>=, 18
          assert_operator word["xMax"].to_f, :<=, 594
        end
      end
    end
  end
end
