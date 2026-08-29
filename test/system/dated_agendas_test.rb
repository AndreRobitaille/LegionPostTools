require "application_system_test_case"

# Browser-driven coverage for dated-agenda management and the member-facing
# published-agenda flow that request tests cannot exercise.
class DatedAgendasSystemTest < ApplicationSystemTestCase
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @user, capability: "manage_agendas")

    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    opening = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", slug: "opening-ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true, body: "Opening")
    report = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", slug: "commander-report", category: "reports", behavior_type: "report_slot", position: 2, active: true, body: "Report")
    @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: opening, position: 1, title: "Opening Ceremony", active: true, body: "Opening")
    @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: report, position: 2, title: "Commander Report", active: true, body: "Report")
    @agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: 1.week.from_now.change(hour: 19, min: 0))

    system_sign_in(@user)
  end

  test "drag-reordering agenda items auto-saves the new order" do
    visit edit_admin_dated_agenda_path(@agenda)

    items = @agenda.dated_agenda_items.ordered.to_a
    first = items.first
    last = items.last

    source = find(".agenda-item-row[data-reorder-id='#{first.id}'] .pos-handle")
    target = find(".agenda-item-row[data-reorder-id='#{last.id}']")
    source.drag_to(target, html5: true)

    assert_selector ".pos-status", text: /saved/i
    assert_not_equal first.id,
      @agenda.dated_agenda_items.ordered.first.id,
      "the first item should no longer be first after dragging it down"
  end

  test "approved agenda hides drag handles and item edit controls" do
    @agenda.approve!(@user)
    visit edit_admin_dated_agenda_path(@agenda)

    assert_selector ".da-lifecycle .st.st--approved"
    assert_selector ".readonly-tip"
    assert_no_selector ".pos-handle"
    assert_no_selector "button.row-del"
  end

  test "dated agenda item list and edit page share the removal modal" do
    item = @agenda.dated_agenda_items.find_by!(title: "Commander Report")
    visit edit_admin_dated_agenda_path(@agenda)

    within ".agenda-item-row[data-reorder-id='#{item.id}']" do
      find("button.row-del[aria-label='Remove #{item.title}']").click
      assert_selector "dialog.confirm-dialog[open]"
      assert_selector ".confirm-record-title", text: item.title
      assert_selector ".confirm-dialog-note", text: /catalog and meeting template will not be changed/i
      find("dialog.confirm-dialog").send_keys(:escape)
      click_link "Edit"
    end

    within ".da-danger-zone" do
      click_button "Remove agenda item"
      assert_selector "dialog.confirm-dialog[open]"
      within "dialog.confirm-dialog" do
        click_button "Remove agenda item"
      end
    end

    assert_current_path edit_admin_dated_agenda_path(@agenda)
    assert_text "Agenda item removed."
    assert_not DatedAgendaItem.exists?(item.id)
  end

  test "dated agenda list trash icon opens the shared record warning" do
    visit admin_dated_agendas_path

    within ".mrow", text: @agenda.title do
      find("button.row-del[aria-label='Delete #{@agenda.title}']").click
      assert_selector "dialog.confirm-dialog[open]"
      assert_selector ".confirm-record-title", text: @agenda.title
      click_button "Cancel"
      assert_no_selector "dialog.confirm-dialog[open]"
    end

    assert DatedAgenda.exists?(@agenda.id)
  end

  test "officer reviews document controls and the responsive Commander's working copy" do
    commander_title = @organization.position_titles.create!(name: "Commander", display_order: 1, required_by_default: true, active: true)
    commander_title.position_assignments.create!(person: @user.person, starts_on: Date.current)
    item = @agenda.dated_agenda_items.find_by!(title: "Opening Ceremony")
    item.update!(
      behavior_type: "roll_call",
      body: "Wording withheld from members",
      show_wording_on_agenda: false,
      show_wording_in_minutes: false,
      commander_notes: "Give three raps, then call the officers."
    )

    visit edit_admin_dated_agenda_agenda_item_path(@agenda, item)

    assert_selector "fieldset.agenda-document-fields legend", text: /Member agenda and minutes/i
    assert_selector "input[name='dated_agenda_item[show_wording_on_agenda]']"
    assert_selector "input[name='dated_agenda_item[show_wording_in_minutes]']"
    assert_selector "fieldset.agenda-document-fields--commander", text: /For officers only/i
    assert_selector "lexxy-editor[name='dated_agenda_item[commander_notes]']"

    visit edit_admin_dated_agenda_path(@agenda)

    assert_link "Print member agenda", href: print_admin_dated_agenda_path(@agenda)
    assert_link "Commander's copy", href: commander_admin_dated_agenda_path(@agenda)
    assert_selector ".agenda-item-flag", text: "Agenda wording hidden"
    assert_selector ".agenda-item-flag", text: "Minutes wording hidden"
    assert_selector ".agenda-item-flag--commander", text: "Commander script"
    assert_button "Refresh officers"

    click_link "Commander's copy"

    assert_selector ".agenda-document-label--commander", text: /Commander's working copy/i
    assert_selector ".commander-cue", text: /Give three raps/
    assert_selector ".roll-call-table", text: /Commander.*Jane Doe/
    assert_no_text "Wording withheld from members"
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")

    page.current_window.resize_to(390, 844)

    assert_selector ".roll-call-table .roll-call-mark", count: 3
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "officer reviews the delete warning and deletes a published agenda" do
    @agenda.approve!(@user)
    @agenda.publish!(@user)
    visit edit_admin_dated_agenda_path(@agenda)

    click_button "Delete dated agenda"

    assert_selector "dialog.confirm-dialog[open]"
    assert_selector ".confirm-record-title", text: @agenda.title
    assert_selector ".confirm-dialog-alert", text: /immediately lose access/
    assert_equal "Cancel", page.evaluate_script("document.activeElement.textContent.trim()")

    find("body").send_keys(:escape)
    assert_no_selector "dialog.confirm-dialog[open]"
    assert_equal "Delete dated agenda", page.evaluate_script("document.activeElement.textContent.trim()")

    click_button "Delete dated agenda"
    within "dialog.confirm-dialog" do
      click_button "Delete dated agenda"
    end

    assert_current_path admin_dated_agendas_path
    assert_text "Dated agenda deleted."
    assert_not DatedAgenda.exists?(@agenda.id)
  end

  test "member navigates from meetings to a published agenda at desktop and phone widths" do
    business_section = @agenda.dated_agenda_sections.create!(title: "Post Business", position: 2)
    @agenda.dated_agenda_items.create!(
      agenda_section: business_section,
      position: 1,
      title: "Community service report",
      summary: "Review this month's service work.",
      behavior_type: "report_slot",
      active: true,
      body: "<ul><li>Completed service work</li><li>Upcoming service work</li></ul>"
    )
    @agenda.dated_agenda_items.create!(
      agenda_section: business_section,
      position: 2,
      title: "Builder Guidance",
      summary: "Screen-only drafting summary.",
      behavior_type: "business_item",
      active: true
    )
    @agenda.approve!(@user)
    @agenda.publish!(@user)

    visit root_path
    click_link "Meetings"

    assert_current_path dated_agendas_path
    assert_selector "a.nav-tab--active[aria-current='page']", text: /Meetings/i
    assert_no_selector ".nav-tab", text: "Records"
    assert_selector ".agenda-docket-row", text: @agenda.title

    find(".agenda-docket-row", text: @agenda.title).click

    assert_current_path dated_agenda_path(@agenda)
    assert_selector ".agenda-masthead h1", text: @agenda.title
    assert_selector ".agenda-chapter-number", count: 2
    assert_selector ".agenda-item-title", text: "Community service report"
    assert_selector ".agenda-item-body ul li", text: "Completed service work"
    assert_selector ".agenda-item-summary", text: "Screen-only drafting summary."
    assert_equal "disc", page.evaluate_script("getComputedStyle(document.querySelector('.agenda-item-body ul')).listStyleType")
    assert_link "Print agenda", href: print_dated_agenda_path(@agenda)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")

    page.current_window.resize_to(390, 844)

    assert_selector ".agenda-masthead h1", text: @agenda.title
    assert_selector ".agenda-chapter-number", count: 2
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")

    click_link "Print agenda"

    assert_current_path print_dated_agenda_path(@agenda)
    assert_selector ".agenda-item-body ul li", text: "Completed service work"
    assert_equal "disc", page.evaluate_script("getComputedStyle(document.querySelector('.agenda-item-body ul')).listStyleType")
    assert_no_selector ".agenda-item-summary"
    assert_no_text "Screen-only drafting summary."
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
