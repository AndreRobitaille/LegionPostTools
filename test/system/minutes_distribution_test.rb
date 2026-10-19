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
