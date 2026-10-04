require "application_system_test_case"

class MeetingDocumentsTest < ApplicationSystemTestCase
  test "members can distinguish and open both meeting documents on desktop and phone" do
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    meeting = create_meeting!(organization: @organization, meeting_body: body, meeting_type: type, starts_at: 1.week.ago, title: "Membership Meeting")
    commander = officer("Commander", "approve_minutes")
    adjutant = officer("Adjutant", "attest_minutes")
    agenda = DatedAgenda.create_from_template!(meeting:)
    agenda.approve!(commander)
    agenda.publish!(commander)
    minutes = MeetingMinutes.create_from_meeting!(meeting:)
    token, = AgentAccessToken.issue!(user: commander, name: "Test approval", expires_in: 1.day)
    minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: token, action: "approve"))
    minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes:, user: adjutant, action: "attest", evidence_note: "Test written attestation."), recorded_by: commander)
    member = User.create!(person: Person.create!(first_name: "General", last_name: "Member"), email_address: "documents-member@example.com")
    system_sign_in(member)
    page.current_window.resize_to(1400, 1000)
    visit meeting_path(meeting)
    assert_selector ".meeting-document-card", count: 2
    assert_selector ".meeting-document-status", text: "Awaiting meeting approval", count: 1
    assert_selector ".meeting-document-open", text: "Open", count: 2
    page.save_screenshot("/tmp/meeting-documents-desktop.png")
    first(".meeting-document-card").send_keys(:tab)
    assert_selector ".meeting-document-card:focus"
    first(".meeting-document-card").click
    assert_current_path meeting_minutes_path(meeting)
    visit meeting_path(meeting)
    page.current_window.resize_to(390, 844)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot("/tmp/meeting-documents-mobile.png")
    find(".meeting-document-card", text: "Agenda").click
    assert_current_path dated_agenda_path(agenda)
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
      assert_equal admin_styles, rich_text_styles
      assert_equal "disc", page.evaluate_script("getComputedStyle(document.querySelector('.minutes-agenda-wording ul')).listStyleType")
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      page.execute_script("document.querySelector('.minutes-item-title').scrollIntoView({ block: 'start' })")
      page.save_screenshot("/tmp/minutes-format-member-#{label}.png")
    end
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    assert_equal admin_styles, rich_text_styles
    assert_equal digest, minutes.current_revision.reload.sha256
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
    page.current_window.resize_to(1400, 1000)
  end

  private

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
          indentation: parseFloat(style('ul', 'marginInlineStart')) > 0,
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
