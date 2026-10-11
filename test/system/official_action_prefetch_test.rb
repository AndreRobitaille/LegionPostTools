require "application_system_test_case"

class OfficialActionPrefetchTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @prefetch_started = Queue.new
    @release_prefetch = Queue.new
    started = @prefetch_started
    release = @release_prefetch
    @delay_prefetch = lambda do
      if request.headers["X-Sec-Purpose"] == "prefetch"
        started << true
        release.pop(timeout: 10)
      end
    end
    Admin::MeetingMinutesController.after_action @delay_prefetch, only: :edit
  end

  teardown do
    @release_prefetch << true
    Admin::MeetingMinutesController.skip_after_action @delay_prefetch, only: :edit
  end

  test "heading hover cannot discard the exact pending attestation before email confirmation" do
    organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization:, meeting_body: body, starts_at: 1.week.ago, title: "Recorded membership meeting")
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    minutes.sections.first.items.create!(title: "Community report", behavior_type: "report_slot", position: 1, body: "Members received the report.")
    officer = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Adjutant"), email_address: "prefetch-adjutant@example.com", email_verified_at: Time.current)
    %w[manage_minutes attest_minutes].each { |capability| officer.permission_grants.create!(capability:) }
    system_sign_in(officer)
    visit admin_meeting_minutes_path(meeting)

    page.execute_script("performance.clearResourceTimings()")
    find_link("Edit heading").hover
    # Turbo debounces hover by 100ms. A bounded wait arms the delayed real response
    # on the original client; the corrected client makes no speculative request.
    prefetched = @prefetch_started.pop(timeout: 1)
    click_button "Attest and share with members"
    assert_selector "h1", text: "Confirm and complete"
    confirmation = officer.official_action_confirmations.sole
    assert_equal "attest", confirmation.action
    assert_equal minutes.id, confirmation.meeting_minutes_id
    assert_nil confirmation.confirmed_at
    assert_nil confirmation.consumed_at
    if prefetched
      @release_prefetch << true
      completed = page.evaluate_async_script(<<~JS, edit_admin_meeting_minutes_path(meeting))
        const [path, done] = arguments;
        const deadline = performance.now() + 5000;
        function waitForResponse() {
          if (performance.getEntriesByType('resource').some(entry => new URL(entry.name).pathname === path)) return done(true);
          if (performance.now() >= deadline) return done(false);
          setTimeout(waitForResponse, 10);
        }
        waitForResponse();
      JS
      assert completed, "the delayed speculative response must finish before requesting confirmation"
    end

    perform_enqueued_jobs do
      click_button "Email me a code and link"
      assert_field "8-digit confirmation code"
    end
    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    assert code
    fill_in "8-digit confirmation code", with: code
    click_button "Confirm and complete"
    assert_current_path admin_meeting_minutes_path(meeting)
    assert_selector ".minutes-status-card h2", text: "Attested — awaiting meeting approval"
    capture_system_screenshot("confirmed-attestation-prefetch-disabled")
    assert_predicate minutes.reload, :attested?
    assert_predicate confirmation.reload, :consumed_at?
    attestation = minutes.current_revision.attestation
    assert_equal officer.id, attestation.attested_by_id
    assert_equal confirmation.id, attestation.official_action_confirmation_id
    body_html = minutes.member_revision.payload.fetch("sections").first.fetch("items").first.fetch("body_html")
    assert_equal "Members received the report.", Nokogiri::HTML.fragment(body_html).text.strip
  end
end
