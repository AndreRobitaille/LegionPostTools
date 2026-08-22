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

    source = find(".section-item-row[data-reorder-id='#{first.id}'] .pos-handle")
    target = find(".section-item-row[data-reorder-id='#{last.id}']")
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

  test "member navigates from meetings to a published agenda at desktop and phone widths" do
    business_section = @agenda.dated_agenda_sections.create!(title: "Post Business", position: 2)
    @agenda.dated_agenda_items.create!(
      agenda_section: business_section,
      position: 1,
      title: "Community service report",
      summary: "Review this month's service work.",
      behavior_type: "report_slot",
      active: true,
      body: "Committee chairs report on completed and upcoming work."
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
    assert_link "Print agenda", href: print_dated_agenda_path(@agenda)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")

    page.current_window.resize_to(390, 844)

    assert_selector ".agenda-masthead h1", text: @agenda.title
    assert_selector ".agenda-chapter-number", count: 2
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
