require "test_helper"

class DatedAgendasControllerTest < ActionDispatch::IntegrationTest
  include LegionFormatHelper

  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    @user = user_with_capabilities
    @draft = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: 2.days.from_now, title: "Draft Agenda", status: "draft")
    @published = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: 1.week.from_now, title: "Published Agenda", status: "draft")
    @published.dated_agenda_items.create!(position: 1, title: "Opening", summary: "The commander calls the meeting to order.", behavior_type: "scripted_ceremony", active: true, body: "Opening words")
    @published.dated_agenda_items.create!(
      position: 2,
      title: "Private Ceremony",
      behavior_type: "scripted_ceremony",
      active: true,
      body: "Withheld ceremony wording",
      show_wording_on_agenda: false,
      commander_notes: "Private Commander instruction"
    )
    business_section = @published.dated_agenda_sections.create!(title: "Post Business", position: 2)
    @published.dated_agenda_items.create!(agenda_section: business_section, position: 1, title: "Old Business", behavior_type: "business_item", active: true, body: "Review unfinished post business.")
    @published.dated_agenda_sections.create!(title: "New Business", position: 3)
    @published.approve!(user_with_capabilities("manage_agendas"))
    @published.publish!(user_with_capabilities("manage_agendas"))
  end

  test "signed out users are redirected from index to new session" do
    get dated_agendas_path

    assert_redirected_to new_session_path
  end

  test "signed out users are redirected from print to new session" do
    get print_dated_agenda_path(@published)

    assert_redirected_to new_session_path
  end

  test "index lists upcoming published agenda and hides draft agenda" do
    sign_in_as(@user)

    get dated_agendas_path

    assert_response :success
    assert_select "h1", text: "Meetings"
    assert_select ".agenda-docket a.agenda-docket-row[href='#{dated_agenda_path(@published)}']" do
      assert_select ".agenda-docket-title", text: "Published Agenda"
      assert_select "time.agenda-docket-date[datetime='#{@published.starts_at.to_date.iso8601}']"
      assert_select ".agenda-docket-meta", text: /Membership/
    end
    assert_select "a", text: "Draft Agenda", count: 0
  end

  test "index shows empty state when no upcoming published agendas exist" do
    @published.update!(starts_at: 1.week.ago)
    sign_in_as(@user)

    get dated_agendas_path

    assert_response :success
    assert_select "h1", text: "Meetings"
    assert_select ".empty h2", text: "No upcoming agendas"
    assert_select ".agenda-docket-row", count: 0
  end

  test "show displays published agenda read only" do
    sign_in_as(@user)

    get dated_agenda_path(@published)

    assert_response :success
    assert_select "h1", text: "Published Agenda"
    assert_select "h2", text: "Order of Business"
    assert_select "h2", text: "Post Business"
    assert_select "h2", text: "New Business"
    assert_select "h3", text: "Opening"
    assert_select "body", text: /Opening words/
    assert_select "body", text: /Withheld ceremony wording/, count: 0
    assert_select "body", text: /Private Commander instruction/, count: 0
    assert_select ".commander-cue", count: 0
    assert_select ".roll-call-table", count: 0
    assert_select ".agenda-org-name", text: @organization.name
    assert_select ".agenda-chapter-rail .agenda-chapter-number", text: "1"
    assert_select ".agenda-chapter-rail .agenda-chapter-number", text: "2"
    assert_select ".agenda-chapter-rail .agenda-chapter-number", text: "3"
    assert_select ".agenda-chapter-empty", text: "No items listed in advance."
    assert_select "a", text: "Edit", count: 0
  end

  test "index excludes past published agendas" do
    past_published = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: 1.week.ago, title: "Past Published Agenda", status: "draft")
    past_published.approve!(user_with_capabilities("manage_agendas"))
    past_published.publish!(user_with_capabilities("manage_agendas"))

    sign_in_as(@user)

    get dated_agendas_path

    assert_response :success
    assert_select "a", text: "Past Published Agenda", count: 0
    assert_select "a[href='#{dated_agenda_path(@published)}'] .agenda-docket-title", text: "Published Agenda"
  end

  test "draft show returns not found" do
    sign_in_as(@user)

    get dated_agenda_path(@draft)

    assert_response :not_found
  end

  test "draft print returns not found" do
    sign_in_as(@user)

    get print_dated_agenda_path(@draft)

    assert_response :not_found
  end

  test "print view renders published agenda without edit link" do
    sign_in_as(@user)

    get print_dated_agenda_path(@published)

    assert_response :success
    assert_select ".agenda-masthead h1", text: "Published Agenda"
    assert_select "h2", text: "Order of Business"
    assert_select "h3", text: "Opening"
    assert_select "body", text: /Opening words/
    assert_select "a", text: "Edit", count: 0
    assert_select "nav", count: 0
    assert_select "body.print-body"
    assert_select "body", text: "Dashboard", count: 0
  end

  test "member print renders a chrome-free agenda document" do
    sign_in_as(user_with_capabilities)

    get print_dated_agenda_path(@published)

    assert_response :success
    assert_select "article.agenda-doc .agenda-masthead h1", text: @published.title
    assert_select ".agenda-org-name", text: @organization.name
    assert_select ".agenda-item .agenda-item-title"
    assert_select "a.back", false
  end

  test "member show renders a readable agenda document with house date format and a print link" do
    sign_in_as(user_with_capabilities)

    get dated_agenda_path(@published)

    assert_response :success
    assert_select "article.agenda-doc .agenda-masthead h1", text: @published.title
    assert_select "a.btn-secondary[href='#{print_dated_agenda_path(@published)}']", text: "Print agenda"
    assert_select "a.agenda-back-link[href='#{dated_agendas_path}']", text: /All meetings/
    assert_select ".agenda-item .agenda-item-title"
    assert_select ".agenda-masthead", text: /#{Regexp.escape(legion_datetime(@published.starts_at))}/
    assert_select "nav.nav-bar a[aria-current='page']", text: "Meetings"
  end

  test "member index lists published agendas in the design system" do
    sign_in_as(user_with_capabilities)

    get dated_agendas_path

    assert_response :success
    assert_select ".page-lead .page-title", text: "Meetings"
    assert_select ".agenda-docket .agenda-docket-row .agenda-docket-title", text: @published.title
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
