require "application_system_test_case"

class TranscriptSourcePrivacyTest < ApplicationSystemTestCase
  setup do
    organization = Organization.create!(name: "Synthetic American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @manager = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Adjutant"), email_address: "source-review@example.test")
    @grant = @manager.permission_grants.create!(capability: "manage_minutes")
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: organization, meeting_body: body, starts_at: 1.day.ago, title: "Synthetic source review")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
  end

  test "restricted intake preserves invalid input for correction and later authority loss refuses source" do
    source = "SYNTHETIC-RESTRICTED-BROWSER-79: Commander described the service project."
    original_minutes = @minutes.attributes
    system_sign_in(@manager)
    visit new_admin_meeting_transcript_path(@meeting)
    fill_in "Paste transcript", with: source
    page.execute_script("document.querySelector('input[type=radio][value=delete_after_acceptance]').value = 'invalid-policy'")

    assert_no_difference "MeetingTranscript.count" do
      click_button "Save restricted transcript"
      assert_selector ".error-summary", text: "Retention policy is not included in the list"
    end
    assert_equal original_minutes, @minutes.reload.attributes
    assert_nil @meeting.reload.transcript
    assert_not_includes find(".error-summary").text, source
    assert_field "Paste transcript", with: source
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      assert_no_horizontal_overflow
      page.execute_script("document.querySelector('.error-summary').scrollIntoView({block: 'start'})")
      capture_system_screenshot("transcript-refused-#{width}")
    end

    choose "meeting_transcript_retention_policy_retain_restricted"
    click_button "Save restricted transcript"
    assert_text "Restricted transcript source added."
    transcript = @meeting.reload.transcript
    assert_equal source, transcript.source_text
    assert_equal "retain_restricted", transcript.retention_policy
    assert_equal @manager.id, transcript.created_by_id
    assert_equal Digest::SHA256.hexdigest(source), transcript.sha256_digest
    assert_equal original_minutes, @minutes.reload.attributes
    click_link "Review transcript"
    assert_selector ".transcript-reader pre", text: source
    assert_text "Retain as restricted source"
    original_source = transcript.attributes
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      assert_no_horizontal_overflow
      page.execute_script("document.querySelector('.transcript-reader').scrollIntoView({block: 'start'})")
      capture_system_screenshot("transcript-reader-#{width}")
    end

    @grant.destroy!
    visit admin_meeting_transcript_path(@meeting)
    assert_current_path root_path
    assert_no_text source
    assert_equal original_source, transcript.reload.attributes
    assert_equal original_minutes, @minutes.reload.attributes
    visit profile_path
    assert_text @manager.person.roster_display_name
    find(".app-menu-btn").click
    click_button "Sign out"
    visit profile_path
    assert_current_path new_session_path
    assert_no_text @manager.email_address
    assert_equal original_source, transcript.reload.attributes
  end

  private

  def assert_no_horizontal_overflow
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("window.innerWidth")
  end
end
