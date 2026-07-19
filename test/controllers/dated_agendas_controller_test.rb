require "test_helper"

class DatedAgendasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    @user = user_with_capabilities
    @draft = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: 2.days.from_now, title: "Draft Agenda", status: "draft")
    @published = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: 1.week.from_now, title: "Published Agenda", status: "draft")
    @published.dated_agenda_items.create!(position: 1, title: "Opening", behavior_type: "scripted_ceremony", active: true, body: "Opening words")
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
    assert_select "h1", text: "Upcoming Published Agendas"
    assert_select "a[href=?]", dated_agenda_path(@published), text: "Published Agenda"
    assert_select "a", text: "Draft Agenda", count: 0
  end

  test "index shows empty state when no upcoming published agendas exist" do
    @published.update!(starts_at: 1.week.ago)
    sign_in_as(@user)

    get dated_agendas_path

    assert_response :success
    assert_select "h1", text: "Upcoming Published Agendas"
    assert_select "p", text: "No upcoming published agendas are available yet.", count: 1
    assert_select "ul li", count: 0
  end

  test "show displays published agenda read only" do
    sign_in_as(@user)

    get dated_agenda_path(@published)

    assert_response :success
    assert_select "h1", text: "Published Agenda"
    assert_select "p", text: "Published agenda"
    assert_select "h2", text: "Opening"
    assert_select "body", text: /Opening words/
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
    assert_select "a[href=?]", dated_agenda_path(@published), text: "Published Agenda"
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
    assert_select "h1", text: "Published Agenda"
    assert_select "h2", text: "Opening"
    assert_select "body", text: /Opening words/
    assert_select "a", text: "Edit", count: 0
    assert_select "nav", count: 0
    assert_select "header", count: 0
    assert_select "body", text: "Dashboard", count: 0
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
