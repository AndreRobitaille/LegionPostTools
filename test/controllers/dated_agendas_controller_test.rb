require "test_helper"

class DatedAgendasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @user = create_user
    @draft = create_dated_agenda!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 2.days.from_now, title: "Draft Agenda")
    @published = create_dated_agenda!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now, title: "Published Agenda", location_name: "Saved Hall", location_address: "123 Main Street")
    @published.dated_agenda_items.create!(position: 1, title: "Opening", behavior_type: "scripted_ceremony", active: true, body: "Opening words")
    manager = create_user("Manager", "manage_agendas")
    @published.approve!(manager)
    @published.publish!(manager)
  end

  test "legacy index redirects authenticated members to meetings" do
    sign_in_as(@user)
    get dated_agendas_path
    assert_redirected_to meetings_path
  end

  test "signed out users are redirected from agenda and print" do
    get dated_agenda_path(@published)
    assert_redirected_to new_session_path
    get print_dated_agenda_path(@published)
    assert_redirected_to new_session_path
  end

  test "published agenda renders its saved place and returns to meeting record" do
    sign_in_as(@user)
    get dated_agenda_path(@published)

    assert_response :success
    assert_select "article.agenda-doc .agenda-masthead h1", text: "Membership Meeting — Agenda"
    assert_select ".agenda-meeting-location-name", text: "Saved Hall"
    assert_select ".agenda-meeting-location-address", text: /123 Main Street/
    assert_select "a.agenda-back-link[href='#{meeting_path(@published.meeting)}']", text: /Meeting record/
    assert_select "a[href='#{print_dated_agenda_path(@published)}']", text: "Open agenda PDF"
    assert_select "body", text: /Opening words/
  end

  test "draft agenda remains private" do
    sign_in_as(@user)
    get dated_agenda_path(@draft)
    assert_response :not_found
    get print_dated_agenda_path(@draft)
    assert_response :not_found
  end

  test "print returns the published member agenda as an inline PDF" do
    sign_in_as(@user)
    rendered = nil
    renderer = lambda do |dated_agenda:, variant:|
      rendered = { dated_agenda: dated_agenda, variant: variant }
      "%PDF-1.7\nmember agenda"
    end

    with_stubbed_class_method(DatedAgendaPdf, :render, renderer) { get print_dated_agenda_path(@published) }

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers.fetch("Content-Disposition"))
    assert_equal({ dated_agenda: @published, variant: "agenda" }, rendered)
  end

  private

  def create_user(label = "Member", *capabilities)
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
