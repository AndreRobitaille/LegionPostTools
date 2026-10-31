require "application_system_test_case"
require_relative "../support/endeavor_history_provider"

class EndeavorHistorySpendTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @previous_enabled = ENV["ENDEAVOR_HISTORY_ENABLED"]
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
    Installation.singleton.update!(setup_completed_at: Time.current)
    @organization = Organization.create!(name: "Harbor American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @user = User.create!(person: Person.create!(first_name: "Morgan", last_name: "Reed"),
      email_address: "history-officer@example.com", email_verified_at: Time.current)
    %w[manage_agendas manage_minutes approve_minutes attest_minutes].each do |capability|
      @user.permission_grants.create!(capability: capability)
    end
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: 2.days.ago, title: "October meeting")
    minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)
    minutes.sections.first.items.create!(title: "Community breakfast", behavior_type: "report_slot", position: 1, body: "Breakfast volunteers confirmed.")
    %w[approve attest].each do |action|
      confirmation = OfficialActionConfirmation.record_external!(minutes: minutes, user: @user, action: action, evidence_note: "Synthetic browser fixture.")
      minutes.public_send("#{action}_with_confirmation!", confirmation: confirmation)
    end
    ENV["ENDEAVOR_HISTORY_ENABLED"] = "1"
    system_sign_in(@user)
  end

  teardown do
    ENV["ENDEAVOR_HISTORY_ENABLED"] = @previous_enabled
  end

  test "officer understands new work and acknowledges a paid history search at desktop and phone widths" do
    [ 1400, 390, 320 ].each do |width|
      page.current_window.resize_to(width, 1200)
      visit new_endeavor_path
      assert_text "History will grow with future minutes."
      assert_text "You can search older discussions later."
      assert_readable_history_form
      page.execute_script("document.querySelector('p.form-help').scrollIntoView({block: 'center'})")
      capture_system_screenshot("endeavor-new-#{width}")
    end
    fill_in "Endeavor name", with: "Community breakfast"
    click_button "Create Endeavor"
    assert_current_path %r{\A/endeavors/\d+\z}
    endeavor = @organization.endeavors.find_by!(title: "Community breakfast")
    assert_current_path endeavor_path(endeavor)
    assert_empty endeavor.history_runs
    within(".endeavor-officer-tools") { click_link "Manage history", exact: true }

    [ 1400, 390, 320 ].each do |width|
      page.current_window.resize_to(width, 1200)
      page.execute_script("scrollTo(0, 0)")
      assert_text "New work needs no search."
      assert_no_text "AI call"
      assert_no_text "Technical details"
      assert_no_selector "textarea[name=guidance]"
      assert_selector "details.history-management-options:not([open])"
      assert_field "I understand this search costs the Post money.", checked: false
      assert_readable_history_form
      capture_system_screenshot("endeavor-history-cost-#{width}")
      page.execute_script("document.getElementById('cost_acknowledged').scrollIntoView({block: 'center'})")
      capture_system_screenshot("endeavor-history-confirmation-#{width}")
    end
    click_button "Search past minutes"
    assert_empty endeavor.history_runs
    assert page.evaluate_script("document.getElementById('cost_acknowledged').validity.valueMissing")

    # A keyboard user can acknowledge the cost and reach the adjacent action.
    find("#cost_acknowledged").send_keys(:space, :tab)
    assert_field "I understand this search costs the Post money.", checked: true
    assert_equal "Search past minutes", page.evaluate_script("document.activeElement.value")
    page.driver.browser.switch_to.active_element.send_keys(:enter)
    assert_text "History search started."
    assert_equal 1, endeavor.history_runs.count
    assert_equal @user, endeavor.history_runs.first.requested_by

    original_provider = EndeavorHistory::Provider.method(:new)
    provider = EndeavorHistoryTestProvider.new
    begin
      EndeavorHistory::Provider.define_singleton_method(:new) { provider }
      perform_enqueued_jobs(only: EndeavorHistoryJob)
    ensure
      EndeavorHistory::Provider.define_singleton_method(:new, original_provider)
    end
    assert_equal "succeeded", endeavor.history_runs.first.reload.status
    assert_equal 4, provider.calls.length
    visit endeavor_path(endeavor)
    assert_text "Breakfast volunteers confirmed."
    visit admin_endeavor_history_path(endeavor)
    find("summary", text: "More options", exact_text: true).click
    assert_field "Other names or search hints"
    find("summary", text: "Technical details", exact_text: true).click
    assert_selector "summary", text: /Run.*Succeeded/
    click_button "Hide history and pause updates"
    assert_text "History is hidden and future updates are paused."
    click_button "Resume and search"
    assert endeavor.reload.history_withdrawn?
    assert_equal 1, endeavor.history_runs.count
    check "I understand this search costs the Post money."
    click_button "Resume and search"
    assert_text "History search started."
    assert_not endeavor.reload.history_withdrawn?
    assert_equal 2, endeavor.history_runs.count
  end

  private

  def assert_readable_history_form
    assert_not page.evaluate_script("document.documentElement.scrollWidth > innerWidth")
    sizes = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('main p, main label, main input[type=submit], main .ft-label'))
        .filter(e => e.getClientRects().length)
        .map(e => ({tag: e.tagName, size: parseFloat(getComputedStyle(e).fontSize)}))
    JS
    assert sizes.all? { |entry| entry["size"] >= (entry["tag"] == "LABEL" ? 13 : 14) }, sizes.inspect
    control_sizes = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('main input[type=submit], main .ft-label'))
        .filter(e => e.getClientRects().length).map(e => parseFloat(getComputedStyle(e).fontSize))
    JS
    assert control_sizes.all? { |size| size >= 16 }, control_sizes.inspect
    assert_selector ".ft-label", text: "I understand this search costs the Post money." if current_path.include?("history")
  end
end
