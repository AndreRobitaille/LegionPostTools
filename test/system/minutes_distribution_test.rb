require "application_system_test_case"
require "open3"
require_relative "../support/minutes_distribution_provider"
require_relative "../support/minutes_distribution_data"

class MinutesDistributionSystemTest < ApplicationSystemTestCase
  include MinutesDistributionData

  setup do
    setup_distribution
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  test "office register remains readable and officers can pause and resume at desktop and narrow widths" do
    add_recipient("district@example.test", office: "District Vice Commander", name: recipient.name)
    system_sign_in(officer)
    visit officer_tools_path
    click_link "Minutes distribution"
    assert_current_path minutes_distribution_path
    [ 1400, 390, 320 ].each do |width|
      page.current_window.resize_to(width, width == 1400 ? 1200 : 844)
      visit minutes_distribution_path
      assert_selector "h1", text: "Minutes distribution"
      assert_selector ".minutes-email-recipient", count: 2
      assert_selector ".minutes-email-groups", text: /Post members.*Roster sync.*Minutes recipients/m
      assert_no_text "Todd"
      within first(".minutes-email-recipient") do
        click_button "Pause"
      end
      assert_text "Office entry saved"
      within first(".minutes-email-recipient") do
        assert_text "Paused"
        click_button "Resume"
      end
      assert_selector "button", text: "Pause", count: 2
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      assert page.evaluate_script("Array.from(document.querySelectorAll('.minutes-email-layout input:not([type=hidden]), .minutes-email-layout button, .minutes-email-layout summary')).filter(e => e.getClientRects().length).every(e => parseFloat(getComputedStyle(e).fontSize) >= 16)")
      capture_system_screenshot("minutes-distribution-#{width}")
      page.execute_script("arguments[0].scrollIntoView({block: 'start'})", first(".minutes-email-recipient"))
      capture_system_screenshot("minutes-recipient-#{width}")
    end
    officer.permission_grants.destroy_all
    visit minutes_distribution_path
    assert_current_path root_path
    assert_no_text recipient.email
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "worker renders real immutable PDFs and corrected-copy email without a real provider" do
    issue = attest
    system_sign_in(officer)
    visit minutes_distribution_path
    port = Capybara.current_session.server.port
    renderer = Object.new
    renderer.define_singleton_method(:render_distribution) do |issue:|
      MeetingMinutesPdf.render_distribution(issue:, base_url: "http://127.0.0.1:#{port}")
    end
    MinutesDistribution::Processor.new(issue, client: provider, renderer:).call
    assert_equal "sent", issue.deliveries.sole.reload.status
    first_bytes = issue.pdf.download
    first_text = pdf_text(first_bytes)
    assert_includes first_text, "Balance: $100."
    assert_match(/Record of authority/i, first_text)
    assert_match(/Awaiting action at a later Membership/, first_text)
    assert_match(/Attested.*Synthetic Adjutant/m, first_text)
    assert_match(/Page 1/, first_text)
    corrected = correct("Balance: $101.")
    MinutesDistribution::Processor.new(corrected, client: provider, renderer:).call
    corrected_text = pdf_text(corrected.pdf.download)
    assert_includes corrected_text, "Balance: $101."
    assert_not_includes corrected_text, "Balance: $100."
    assert_equal first_bytes, issue.reload.pdf.download
    assert_equal 2, provider.messages.size
    assert_match(/Corrected minutes/, provider.messages.last.dig(:dataVariables, "subject"))
    approve
    MinutesDistribution::Processor.new(corrected, client: provider, renderer:).call
    assert_equal 2, provider.messages.size
    visit admin_meeting_minutes_path(minutes.meeting)
    assert_selector "section[aria-label='Minutes email']", text: /No new email needed for unchanged approval/
    page.current_window.resize_to(390, 844)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    capture_system_screenshot("minutes-distribution-approved-390")
    if ENV["SYSTEM_TEST_CAPTURE_DIR"].present?
      File.binwrite(Rails.root.join(ENV.fetch("SYSTEM_TEST_CAPTURE_DIR"), "minutes-first.pdf"), first_bytes)
      File.binwrite(Rails.root.join(ENV.fetch("SYSTEM_TEST_CAPTURE_DIR"), "minutes-corrected.pdf"), corrected.pdf.download)
    end
  end

  test "officers deliberately edit settings and wording with visible variables and a filled in preview" do
    system_sign_in(officer)
    visit minutes_distribution_path
    assert_no_field "Address for replies"
    assert_no_field "Subject"
    within "#delivery-settings" do
      assert_text "Automatic email enabled"
      click_link "Edit delivery settings"
    end
    fill_in "Address for replies", with: "unsaved@example.test"
    find("summary", text: "Loops connection setup").click
    assert_no_field "Post members list ID"
    assert_text "These lists are already in use"
    assert_text "This check records your review"
    capture_system_screenshot("minutes-delivery-edit-1400")
    click_link "Cancel"
    assert_equal "reply@example.test", organization.minutes_distribution_setting.reload.reply_to
    assert_no_field "Address for replies"
    click_link "Edit email wording"
    assert_field "Subject", with: MinutesDistribution::EmailTemplate::DEFAULT_SUBJECT
    fill_in "Cover note", with: "Please retain this copy for "
    find("button", text: /\APost name\s*\{\{post_name\}\}\z/).click
    assert_field "Cover note", with: "Please retain this copy for {{post_name}}"
    within ".minutes-email-preview" do
      assert_text "Please retain this copy for Synthetic Legion Post"
      select "Corrected copy", from: "Example copy"
      assert_selector "[data-email-wording-target='subjectPreview']", text: /Corrected minutes/
      assert_text MinutesDistribution::EmailTemplate::CORRECTION_NOTICE
      assert_text "Minutes status — added automatically"
      assert_text "Minutes PDF attached"
      select "Approved copy", from: "Example copy"
      assert_text "Attested and approved"
      assert_no_text MinutesDistribution::EmailTemplate::CORRECTION_NOTICE
      select "Corrected copy", from: "Example copy"
    end
    [ 1400, 390, 320 ].each do |width|
      page.current_window.resize_to(width, width == 1400 ? 1200 : 844)
      page.execute_script("arguments[0].scrollIntoView({block: 'start'})", find("#email-wording"))
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      assert page.evaluate_script("Array.from(document.querySelectorAll('#email-wording input, #email-wording textarea, #email-wording button, #email-wording select')).filter(e => e.getClientRects().length && e.type !== 'hidden').every(e => parseFloat(getComputedStyle(e).fontSize) >= 16)")
      capture_system_screenshot("minutes-wording-edit-#{width}")
      page.execute_script("arguments[0].scrollIntoView({block: 'start'})", find(".minutes-email-letter"))
      capture_system_screenshot("minutes-email-letter-#{width}")
    end
    fill_in "Cover note", with: "Please retain {{unknown}}."
    click_button "Save email wording"
    assert_selector "[role='alert']", text: /Unknown variable/
    assert_field "Cover note", with: "Please retain {{unknown}}."
    fill_in "Cover note", with: "Please retain the {{meeting_label}} minutes."
    click_button "Save email wording"
    assert_text "Email wording saved for future attestations"
    assert_no_field "Subject"
    assert_equal "Please retain the {{meeting_label}} minutes.", organization.minutes_distribution_setting.reload.email_cover_note_template
    [ 1400, 390, 320 ].each do |width|
      page.current_window.resize_to(width, width == 1400 ? 1200 : 844)
      visit minutes_distribution_path
      assert_no_field "Address for replies"
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      page.execute_script("arguments[0].scrollIntoView({block: 'start'})", find("#delivery-settings"))
      capture_system_screenshot("minutes-delivery-saved-#{width}")
    end
    click_link "Edit email wording"
    fill_in "Cover note", with: "Unsaved older form."
    organization.minutes_distribution_setting.reload.update!(email_cover_note_template: "A newer officer's wording.")
    click_button "Save email wording"
    assert_selector "[role='alert']", text: "These settings changed while you were editing"
    assert_field "Cover note", with: "Unsaved older form."
    assert_button "Save email wording", disabled: true
    click_link "Reload latest settings"
    assert_field "Cover note", with: "A newer officer's wording."
    assert_button "Save email wording", disabled: false
    assert_empty provider.messages
    assert_empty organization.minutes_distributions
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def pdf_text(bytes)
    Tempfile.create([ "synthetic-minutes", ".pdf" ]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      text, status = Open3.capture2("pdftotext", "-layout", file.path, "-")
      assert status.success?
      text
    end
  end
end
