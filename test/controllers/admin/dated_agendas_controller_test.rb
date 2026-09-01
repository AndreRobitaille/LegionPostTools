require "test_helper"

class Admin::DatedAgendasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    entry = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true)
    @type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: entry, position: 1, title: "Opening", active: true)
    @agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now)
    @manager = create_user("Manager", "manage_agendas")
  end

  test "legacy index redirects agenda managers to meetings" do
    sign_in_as(@manager)
    get admin_dated_agendas_path
    assert_redirected_to admin_meetings_path
  end

  test "users without agenda authority are denied" do
    sign_in_as(create_user("Member"))
    get edit_admin_dated_agenda_path(@agenda)
    assert_redirected_to root_path
  end

  test "edit shows lifecycle tools and meeting-owned details" do
    sign_in_as(@manager)
    get edit_admin_dated_agenda_path(@agenda)

    assert_response :success
    assert_select ".da-lifecycle .st.st--draft"
    assert_select "form[action='#{approve_admin_dated_agenda_path(@agenda)}']"
    assert_select ".agenda-meeting-snapshot", text: /Change meeting details/
    assert_select "a[href='#{edit_admin_meeting_path(@agenda.meeting)}']"
    assert_select "input[name='dated_agenda[starts_at]']", count: 0
    assert_select "a[href='#{print_admin_dated_agenda_path(@agenda)}']", text: "Open member agenda PDF"
    assert_select "a[href='#{commander_admin_dated_agenda_path(@agenda)}']", count: 0
  end

  test "approve publish and reopen preserve the human lifecycle" do
    sign_in_as(@manager)

    patch approve_admin_dated_agenda_path(@agenda)
    assert_equal "approved", @agenda.reload.status
    assert_equal @manager, @agenda.approved_by
    patch publish_admin_dated_agenda_path(@agenda)
    assert_equal "published", @agenda.reload.status
    assert_equal @manager, @agenda.published_by
    patch reopen_admin_dated_agenda_path(@agenda)
    assert_equal "draft", @agenda.reload.status
    assert_equal @manager, @agenda.reopened_by
  end

  test "invalid lifecycle transition reports the model error" do
    sign_in_as(@manager)
    patch publish_admin_dated_agenda_path(@agenda)

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Approve this agenda before publishing it.", flash[:alert]
  end

  test "destroy removes the agenda but keeps its meeting" do
    sign_in_as(@manager)
    meeting = @agenda.meeting

    assert_difference -> { DatedAgenda.count }, -1 do
      assert_no_difference -> { Meeting.count } do
        delete admin_dated_agenda_path(@agenda)
      end
    end

    assert_redirected_to admin_meeting_path(meeting)
    assert_response :see_other
    assert_equal "Dated agenda deleted. The meeting remains in the record.", flash[:notice]
  end

  test "another organization's agenda is unreachable" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_body = other.meeting_bodies.create!(name: "Membership", slug: "other-membership")
    other_type = other.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    other_agenda = create_dated_agenda!(organization: other, meeting_body: other_body, meeting_type: other_type, starts_at: 1.week.from_now, title: "Other Meeting")
    sign_in_as(@manager)

    delete admin_dated_agenda_path(other_agenda)

    assert_response :not_found
    assert DatedAgenda.exists?(other_agenda.id)
  end

  test "agenda manager receives the member PDF but not the private notes PDF" do
    sign_in_as(@manager)
    variants = []
    renderer = lambda do |dated_agenda:, variant:|
      variants << [ dated_agenda, variant ]
      "%PDF-1.7\n#{variant}"
    end

    with_stubbed_class_method(DatedAgendaPdf, :render, renderer) do
      get commander_admin_dated_agenda_path(@agenda)
      assert_redirected_to edit_admin_dated_agenda_path(@agenda)
      assert_equal "Only the current Commander or Adjutant can open the private notes PDF.", flash[:alert]
      get print_admin_dated_agenda_path(@agenda)
      assert_response :success
    end

    assert_equal [ [ @agenda, "agenda" ] ], variants
  end

  test "current Commander and Adjutant receive the private notes PDF" do
    variants = []
    renderer = lambda do |dated_agenda:, variant:|
      variants << [ dated_agenda, variant ]
      "%PDF-1.7\n#{variant}"
    end

    with_stubbed_class_method(DatedAgendaPdf, :render, renderer) do
      {
        "Commander" => "approve_minutes",
        "Adjutant" => "attest_minutes"
      }.each do |role_name, official_capability|
        user = create_user(role_name)
        assign_position_capabilities(user, role_name, "manage_agendas", official_capability)
        sign_in_as(user)

        get edit_admin_dated_agenda_path(@agenda)
        assert_response :success
        assert_select "a[href='#{commander_admin_dated_agenda_path(@agenda)}']", text: "Cmdr Notes PDF"

        get commander_admin_dated_agenda_path(@agenda)
        assert_response :success
      end
    end

    assert_equal [ [ @agenda, "officer_notes" ], [ @agenda, "officer_notes" ] ], variants
  end

  private

  def create_user(label, *capabilities)
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end

  def assign_position_capabilities(user, role_name, *capabilities)
    title = @organization.position_titles.create!(name: role_name, display_order: @organization.position_titles.count + 1)
    capabilities.each { |capability| title.position_capability_grants.create!(capability:) }
    title.position_assignments.create!(person: user.person, starts_on: Date.current)
  end
end
