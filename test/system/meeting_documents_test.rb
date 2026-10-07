require "application_system_test_case"
require "base64"

class MeetingDocumentsTest < ApplicationSystemTestCase
  test "members can distinguish and open both meeting documents on desktop and phone" do
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", locality: "Example City, Wisconsin", mailing_address: "P.O. Box 11\nExample City, WI 54000", public_email: "post@example.com", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    meeting = create_meeting!(organization: @organization, meeting_body: body, meeting_type: type, starts_at: 1.week.ago, title: "Membership Meeting", location_name: "Community Hall", location_address: "123 Example Street\nExample City, WI 54000")
    commander = officer("Commander", "approve_minutes")
    adjutant = officer("Adjutant", "attest_minutes")
    agenda = DatedAgenda.create_from_template!(meeting:)
    agenda.dated_agenda_items.create!(title: "Community breakfast", behavior_type: "business_item", position: 1, body: "<p>Discuss plans for a community breakfast.</p><ul><li>Volunteer teams</li><li>Proposed date and supplies</li></ul>", show_wording_on_agenda: true, show_wording_in_minutes: true, commander_notes: "Private meeting instructions.")
    agenda.dated_agenda_items.create!(title: "Membership report", behavior_type: "report_slot", position: 2, summary: "Review membership and welcome new members.")
    agenda.approve!(commander)
    agenda.publish!(commander)
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    item = minutes.items.find_by!(title: "Community breakfast")
    item.update!(body: "<p>Members discussed the volunteer teams and agreed to hold a community breakfast next month.</p>")
    item.outcomes.create!(kind: "motion", text: "Hold a community breakfast next month, with the final date coordinated by the volunteer committee.", disposition: "adopted", mover_name: "Alex Member", seconder_name: "Pat Member", vote_summary: "Passed unanimously.", position: 1)
    minutes.attendance_entries.create!(office_name: "Commander", person_name: "Test Commander", status: "present", position: 1)
    minutes.attendance_entries.create!(office_name: "Adjutant", person_name: "Test Adjutant", status: "present", position: 2)
    minutes.attendance_entries.create!(office_name: "Sergeant at Arms", person_name: "Robin Member", status: "excused", position: 3)
    token, = AgentAccessToken.issue!(user: commander, name: "Test approval", expires_in: 1.day)
    minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: token, action: "approve"))
    minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes:, user: adjutant, action: "attest", evidence_note: "Test written attestation."), recorded_by: commander)
    type.update!(name: "Renamed Template", slug: "renamed-template")
    member = User.create!(person: Person.create!(first_name: "General", last_name: "Member"), email_address: "documents-member@example.com")
    system_sign_in(member)
    page.current_window.resize_to(1400, 1000)
    visit meeting_path(meeting)
    assert_selector ".meeting-document-card", count: 2
    assert_selector ".meeting-document-status", text: "Awaiting meeting approval", count: 1
    assert_selector ".meeting-document-open", text: "Open", count: 2
    page.save_screenshot("/tmp/meeting-documents-desktop.png")
    first(".meeting-document-card").hover
    assert page.evaluate_script("Array.from(document.querySelectorAll('.meeting-document-card:hover .meeting-document-open, .meeting-document-card:hover .meeting-document-open > span')).every(node => getComputedStyle(node).textDecorationLine === 'none' && getComputedStyle(node).textShadow !== 'none')")
    page.save_screenshot("/tmp/meeting-documents-hover-desktop.png")
    first(".meeting-document-card").send_keys(:tab)
    assert_selector ".meeting-document-card:focus"
    first(".meeting-document-card").click
    assert_current_path meeting_minutes_path(meeting)
    assert_selector ".agenda-meeting-heading h1", text: "Membership Meeting"
    assert_selector ".member-meeting-document article.agenda-doc", count: 1
    assert_selector "a.agenda-print-link", text: "Open minutes PDF"
    assert_selector ".minutes-doc-outcome-text", text: /Hold a community breakfast/
    assert_selector ".minutes-doc-outcome-facts", text: /Alex Member.*Pat Member.*Passed.*Passed unanimously/mi
    assert_selector ".minutes-doc-attendance tbody", text: /Robin Member.*Excused/m
    assert_no_text "Private meeting instructions."
    assert_document_readability
    save_document_screenshot("/tmp/member-minutes-paper-desktop.png")
    summary = find(".member-minutes-provenance summary")
    summary.send_keys(:space)
    assert_selector ".member-minutes-provenance[open]", text: /Commander draft handoff.*Adjutant attestation/m
    summary.send_keys(:space)
    assert_no_selector ".member-minutes-provenance[open]"
    visit dated_agenda_path(agenda)
    assert_selector ".agenda-meeting-heading h1", text: "Membership Meeting — Agenda"
    assert_selector ".agenda-item-body", text: /Discuss plans for a community breakfast/
    assert_selector ".agenda-item-summary", text: "Review membership and welcome new members."
    assert_no_text "Private meeting instructions."
    assert_document_readability
    save_document_screenshot("/tmp/member-agenda-paper-desktop.png")
    visit meeting_path(meeting)
    page.current_window.resize_to(390, 844)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot("/tmp/meeting-documents-mobile.png")
    find(".meeting-document-card", text: "Agenda").click
    assert_current_path dated_agenda_path(agenda)
    assert_selector ".agenda-meeting-heading h1", text: "Membership Meeting — Agenda"
    assert_document_readability
    save_document_screenshot("/tmp/member-agenda-paper-mobile.png")
    visit meeting_minutes_path(meeting)
    assert_selector ".agenda-meeting-heading h1", text: "Membership Meeting"
    assert_selector "a.agenda-print-link", text: "Open minutes PDF"
    assert_document_readability
    assert_equal 1, page.evaluate_script("getComputedStyle(document.querySelector('.minutes-doc-outcome-facts')).gridTemplateColumns.split(' ').length")
    save_document_screenshot("/tmp/member-minutes-paper-mobile.png")
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  test "attested member minutes retain rich text formatting on desktop phone and print" do
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: 1.week.ago, title: "Membership Meeting")
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    minutes.sections.first.items.create!(
      title: "Community breakfast report", behavior_type: "report_slot", position: 1,
      agenda_body: "<ul><li>Review volunteer needs.</li></ul>",
      body: <<~HTML
        <p>The members reviewed the <strong class="lexxy-content__bold">breakfast plan</strong>.</p>
        <ul><li>Recruit volunteers.</li><li class="lexxy-nested-listitem"><ul><li>Confirm kitchen helpers.</li></ul></li><li>Prepare supplies.</li></ul>
        <ol><li>Publish the date.</li><li>Open registration.</li></ol>
        <blockquote><p>All members are welcome to help.</p></blockquote>
        <p><em class="lexxy-content__italic">Follow-up</em>: <a href="https://example.com/breakfast">volunteer information</a>.</p>
      HTML
    )
    adjutant = officer("Adjutant", "attest_minutes")
    adjutant.permission_grants.create!(capability: "manage_minutes")
    token, = AgentAccessToken.issue!(user: adjutant, name: "Test attestation", expires_in: 1.day)
    minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: token, action: "attest"))
    digest = minutes.current_revision.sha256

    system_sign_in(adjutant)
    visit admin_meeting_minutes_path(meeting)
    assert_no_selector ".member-meeting-document"
    assert_selector ".minutes-outline", count: 1
    assert_selector ".minutes-recorded-wording", text: "breakfast plan"
    admin_styles = rich_text_styles
    assert_equal "disc", admin_styles.fetch("bullets")
    assert_equal "decimal", admin_styles.fetch("numbers")
    assert_equal "none", admin_styles.fetch("nestingMarker")
    page.execute_script("document.querySelector('.minutes-item-title').scrollIntoView({ block: 'start' })")
    page.save_screenshot("/tmp/minutes-format-admin-desktop.png")
    member = User.create!(person: Person.create!(first_name: "General", last_name: "Member"), email_address: "formatting-member@example.com")
    system_sign_in(member)

    [ [ 1400, 1000, "desktop" ], [ 390, 844, "mobile" ] ].each do |width, height, label|
      page.current_window.resize_to(width, height)
      visit meeting_minutes_path(meeting)
      assert_selector ".member-minutes-status", text: "Awaiting meeting approval"
      assert_equal admin_styles.merge("nestedBullets" => "circle"), rich_text_styles
      assert_equal "disc", page.evaluate_script("getComputedStyle(document.querySelector('.minutes-agenda-wording ul')).listStyleType")
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      page.execute_script("document.querySelector('.minutes-item-title').scrollIntoView({ block: 'start' })")
      page.save_screenshot("/tmp/minutes-format-member-#{label}.png")
    end
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_equal admin_styles.merge("nestedBullets" => "circle"), rich_text_styles
    assert_operator page.evaluate_script("document.querySelector('.member-minutes-provenance dl').getBoundingClientRect().height"), :>, 0
    assert_equal digest, minutes.current_revision.reload.sha256
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
    page.current_window.resize_to(1400, 1000)
  end

  private

  def assert_document_readability
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    assert page.evaluate_script("Array.from(document.querySelectorAll('.agenda-item-body, .agenda-item-summary, .minutes-doc-outcome-text, .minutes-doc-attendance tbody th, .minutes-doc-attendance tbody td')).every(node => parseFloat(getComputedStyle(node).fontSize) >= 16)")
    assert page.evaluate_script("Array.from(document.querySelectorAll('.agenda-org-locality, .agenda-meeting-when, .agenda-meeting-location-address, .agenda-doc-footer')).every(node => parseFloat(getComputedStyle(node).fontSize) >= 14)")
    assert_operator page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.agenda-meeting-location-label')).fontSize)"), :>=, 13
    if has_selector?(".minutes-recorded-wording")
      assert_operator page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.minutes-recorded-wording > .agenda-item-body')).borderLeftWidth)"), :>, 0
    end
  end

  def save_document_screenshot(path)
    size = page.driver.browser.execute_cdp("Page.getLayoutMetrics").fetch("cssContentSize")
    result = page.driver.browser.execute_cdp("Page.captureScreenshot", captureBeyondViewport: true, clip: size.merge("scale" => 1))
    File.binwrite(path, Base64.decode64(result.fetch("data")))
  end

  def rich_text_styles
    page.evaluate_script(<<~JS)
      (() => {
        const body = document.querySelector('.minutes-recorded-wording');
        const style = (selector, property) => getComputedStyle(body.querySelector(selector))[property];
        return {
          bullets: style('ul', 'listStyleType'),
          numbers: style('ol', 'listStyleType'),
          nestedBullets: style('ul ul', 'listStyleType'),
          nestingMarker: style('li.lexxy-nested-listitem', 'listStyleType'),
          bold: style('strong', 'fontWeight'),
          italic: style('em', 'fontStyle'),
          quote: parseFloat(style('blockquote', 'borderLeftWidth')) > 0,
          indentation: parseFloat(style('ul', 'marginInlineStart')) + parseFloat(style('ul', 'paddingInlineStart')) > 0,
          link: style('a', 'textDecorationLine')
        };
      })()
    JS
  end

  def officer(name, capability)
    person = Person.create!(first_name: "Test", last_name: name)
    user = User.create!(person:, email_address: "documents-#{name.downcase}@example.com")
    user.permission_grants.create!(capability:)
    position = @organization.position_titles.create!(name:, display_order: @organization.position_titles.count + 1)
    position.position_assignments.create!(person:, starts_on: 1.year.ago.to_date)
    user
  end
end
