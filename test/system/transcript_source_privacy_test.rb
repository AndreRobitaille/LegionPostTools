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
      assert_rendered_font_floor(".transcript-textarea, .transcript-file", 16)
      assert_rendered_font_floor(".transcript-source-panel > p:not(.meeting-workflow-kicker), .transcript-privacy-note p", 16)
      assert_rendered_font_floor(".transcript-retention legend span, .transcript-choice strong em, .transcript-or", 13)
      assert_rendered_font_floor(".transcript-choice small, .fl-help", 14)
      assert_no_horizontal_overflow
      page.execute_script("document.querySelector('.error-summary').scrollIntoView({block: 'start'})")
      capture_system_screenshot("transcript-refused-#{width}")
      page.execute_script("document.querySelector('.transcript-retention').scrollIntoView({block: 'start'})")
      capture_system_screenshot("transcript-retention-#{width}")
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
      assert_rendered_font_floor(".transcript-reader pre, .transcript-facts dd", 16)
      assert_rendered_font_floor(".transcript-facts dt, .transcript-reader-head span", 13)
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

  test "a real Unicode text-file upload preserves bytes and later source authority" do
    raw = "\uFEFFCommander: José described the synthetic service project.\r\n"
    normalized = "Commander: José described the synthetic service project.\n"
    original_minutes = @minutes.attributes
    system_sign_in(@manager)
    visit new_admin_meeting_transcript_path(@meeting)

    Tempfile.create([ "unicode-source", ".txt" ]) do |file|
      file.binmode
      file.write(raw)
      file.flush
      attach_file "Upload a transcript file", file.path
      choose "meeting_transcript_retention_policy_retain_restricted"
      click_button "Save restricted transcript"
      assert_text "Restricted transcript source added."
      transcript = @meeting.reload.transcript
      assert_equal raw.b, transcript.text_file.download.b
      assert_equal normalized, transcript.source_text
      assert_equal Digest::SHA256.hexdigest(raw), transcript.sha256_digest
      assert_equal raw.bytesize, transcript.byte_size
      assert_equal @manager.id, transcript.created_by_id
      assert_equal "retain_restricted", transcript.retention_policy
      assert_equal original_minutes, @minutes.reload.attributes
      original_source = transcript.attributes

      click_link "Review transcript"
      assert_selector ".transcript-reader pre", text: "José described the synthetic service project."
      [ 1400, 390 ].each do |width|
        page.current_window.resize_to(width, 1000)
        assert_no_horizontal_overflow
        assert_operator find(".transcript-reader pre").evaluate_script("parseFloat(getComputedStyle(this).fontSize)"), :>=, 16
        page.execute_script("document.querySelector('.transcript-reader').scrollIntoView({block: 'start'})")
        capture_system_screenshot("transcript-upload-reader-#{width}")
      end
      assert_equal original_source, transcript.reload.attributes
      assert_equal original_minutes, @minutes.reload.attributes

      @grant.destroy!
      visit admin_meeting_transcript_path(@meeting)
      assert_current_path root_path
      assert_no_text "José described the synthetic service project."
      assert_equal original_source, transcript.reload.attributes
      assert_equal raw.b, transcript.text_file.download.b
      assert_equal original_minutes, @minutes.reload.attributes
      visit profile_path
      assert_text @manager.person.roster_display_name
    end
  end

  test "final corrected attestation schedules removal and failed upload deletion recovers without changing member minutes" do
    travel_to Time.utc(2026, 11, 1, 18)
    %w[attest_minutes record_minutes_approval].each { |capability| @manager.permission_grants.create!(capability:) }
    organization = @meeting.organization
    position = organization.position_titles.create!(name: "Adjutant", active: true, display_order: 1)
    position.position_assignments.create!(person: @manager.person, starts_on: Date.new(2026, 1, 1))
    source = "\uFEFFSYNTHETIC-RETENTION-READER-79: José described the private source.\r\n"
    system_sign_in(@manager)
    visit new_admin_meeting_transcript_path(@meeting)
    assert_text "window starts when the Adjutant attests the corrections"
    Tempfile.create([ "retention-reader", ".txt" ]) do |file|
      file.binmode
      file.write(source)
      file.flush
      attach_file "Upload a transcript file", file.path
      choose "meeting_transcript_retention_policy_delete_after_acceptance"
      click_button "Save restricted transcript"
      assert_text "Restricted transcript source added."
    end
    transcript = @meeting.reload.transcript
    assert_equal source.b, transcript.text_file.download.b
    blob_id = transcript.text_file.blob.id
    storage = transcript.text_file.blob.service
    key = transcript.text_file.blob.key
    metadata = transcript.attributes.slice("organization_id", "meeting_id", "created_by_id", "source_kind", "retention_policy",
      "original_filename", "byte_size", "media_type", "sha256_digest")
    @minutes.sections.first.items.create!(title: "Community report", behavior_type: "report_slot", position: 1,
      body: "Twelve fictional families received assistance.")
    @minutes.attest_with_confirmation!(confirmation: retention_confirmation("attest"))
    approving = create_meeting!(organization: organization, meeting_body: @meeting.meeting_body, starts_at: 1.hour.ago)
    @minutes.record_membership_approval_with_confirmation!(confirmation: retention_confirmation("record_membership_approval",
      approving_meeting_id: approving.id, disposition: "approved_as_corrected", corrections_pending: true,
      factual_note: "Correct the fictional report heading."))
    visit admin_meeting_transcript_path(@meeting)
    assert_selector ".transcript-reader pre", text: "José described the private source."
    assert_text "Starts when the minutes become final"
    assert_nil transcript.reload.scheduled_purge_at

    # These fixture acts use real audited methods; the separate approval journey exercises their UI.
    travel_to Time.utc(2026, 11, 10, 18)
    @minutes.update!(title: "Corrected fictional report")
    @minutes.attest_with_confirmation!(confirmation: retention_confirmation("attest"))
    saved_revision = @minutes.reload.member_revision.attributes
    saved_approval = @minutes.membership_approval.attributes
    assert_equal Time.utc(2026, 11, 1, 18), @minutes.membership_approval.recorded_at
    assert_equal Time.utc(2026, 12, 10, 18), transcript.reload.scheduled_purge_at
    visit admin_meeting_transcript_path(@meeting)
    assert_text "SCHEDULED REMOVAL"
    assert_text "01 NOV 2026 · 12:00"
    assert_text "10 DEC 2026 · 12:00 (Post time)"
    assert_text "Post time"
    assert_selector ".transcript-reader pre", text: "José described the private source."
    capture_retention_state("scheduled")
    travel_to Time.utc(2026, 12, 10, 18)
    original_delete = storage.method(:delete)
    storage.define_singleton_method(:delete) do |requested_key|
      raise IOError, "Synthetic storage outage" if requested_key == key
      original_delete.call(requested_key)
    end
    begin
      assert_raises(PurgeMeetingTranscriptsJob::BatchRemovalError) { PurgeMeetingTranscriptsJob.perform_now }
    ensure
      storage.singleton_class.remove_method(:delete)
    end
    assert storage.exist?(key)
    assert ActiveStorage::Blob.exists?(blob_id)
    assert_nil transcript.reload.purged_at
    visit admin_meeting_transcript_path(@meeting)
    assert_text "Removal is pending"
    assert_no_selector ".transcript-reader pre"
    assert_no_text "José described the private source."
    capture_retention_state("pending")
    travel_to Time.utc(2026, 12, 10, 19)
    PurgeMeetingTranscriptsJob.perform_now
    assert_not storage.exist?(key)
    assert_not ActiveStorage::Blob.exists?(blob_id)
    assert_not transcript.reload.text_file.attached?
    assert_equal "transcript_retention", transcript.purged_by_service
    assert_nil transcript.purged_by_id
    assert_equal metadata, transcript.attributes.slice(*metadata.keys)
    assert_equal saved_revision, @minutes.reload.member_revision.attributes
    assert_equal saved_approval, @minutes.membership_approval.attributes
    visit admin_meeting_transcript_path(@meeting)
    assert_text "transcript content has been purged"
    assert_text "by automatic retention"
    assert_no_text "Removal is pending"
    assert_no_selector ".transcript-reader pre"
    assert_no_text "José described the private source."
    capture_retention_state("removed")
    source_response = page.evaluate_async_script(<<~JS, "/api/meetings/#{@meeting.id}/transcript?include_content=true")
      const [url, done] = arguments;
      fetch(url).then(async response => done({status: response.status, cache: response.headers.get('Cache-Control'), body: await response.json()}));
    JS
    assert_equal 200, source_response.fetch("status")
    assert_equal "no-store", source_response.fetch("cache")
    assert_nil source_response.dig("body", "transcript", "content")
    assert_equal false, source_response.dig("body", "transcript", "source_available")
    @grant.destroy!
    visit admin_meeting_transcript_path(@meeting)
    assert_current_path root_path
    assert_no_text "SYNTHETIC-RETENTION-READER-79"
    visit meeting_minutes_path(@meeting)
    assert_text "Corrected fictional report"
    assert_text "Twelve fictional families received assistance."
    assert_no_text "SYNTHETIC-RETENTION-READER-79"
    assert_equal saved_revision, @minutes.reload.member_revision.attributes
    find(".app-menu-btn").click
    click_button "Sign out"
    visit meeting_minutes_path(@meeting)
    assert_current_path new_session_path
    assert_no_text "Twelve fictional families received assistance."
  ensure
    storage&.delete(key) if key && storage.exist?(key)
    travel_back
    page.current_window.resize_to(1400, 1400)
  end

  private

  def retention_confirmation(action, **action_payload)
    OfficialActionConfirmation.record_external!(minutes: @minutes, user: @manager, action:, action_payload:,
      evidence_note: "Synthetic written confirmation for retention browser setup.")
  end

  def capture_retention_state(name)
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      assert_rendered_font_floor(".transcript-facts dd, .transcript-reader .minutes-empty-note", 16)
      assert_rendered_font_floor(".transcript-facts dt, .transcript-reader-head span", 13)
      assert_no_horizontal_overflow
      page.execute_script("document.querySelector('.transcript-facts').scrollIntoView({block: 'start'})")
      capture_system_screenshot("transcript-#{name}-#{width}")
      page.execute_script("document.querySelector('.transcript-reader').scrollIntoView({block: 'start'})")
      capture_system_screenshot("transcript-#{name}-reader-#{width}")
    end
  end

  def assert_rendered_font_floor(selector, floor)
    sizes = page.evaluate_script("Array.from(document.querySelectorAll(#{selector.to_json})).map(element => parseFloat(getComputedStyle(element).fontSize))")
    assert_not_empty sizes, "Expected rendered text for #{selector}"
    sizes.each { |size| assert_operator size, :>=, floor, "Rendered #{selector} must meet the #{floor}px floor" }
  end

  def assert_no_horizontal_overflow
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("window.innerWidth")
  end
end
