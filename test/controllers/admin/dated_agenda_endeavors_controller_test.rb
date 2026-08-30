require "test_helper"

class Admin::DatedAgendaEndeavorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    @agenda = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: 1.week.from_now, title: "September Membership", status: "draft")
    @manager = create_user("Manager", manage_agendas: true)
    @member = create_user("Member")
    @endeavor = @organization.endeavors.create!(created_by: @manager, meeting_body: @meeting_body, title: "Car Show", summary: "Confirm permits", details: "Permit history", importance: "important", raise_by_on: 1.week.from_now.to_date)
  end

  test "picker groups active Endeavor for a chosen section" do
    sign_in_as(@manager)

    get new_admin_dated_agenda_endeavor_path(@agenda, dated_agenda_section_id: @agenda.default_agenda_section.id)

    assert_response :success
    assert_select "h1", text: "Add Endeavor"
    assert_select ".picker-destination", text: /Order of Business/
    assert_select ".endeavor-bucket--necessity", text: /Car Show/
  end

  test "manager adds a snapshot to the selected agenda section" do
    sign_in_as(@manager)

    assert_difference -> { @agenda.dated_agenda_items.count }, 1 do
      post admin_dated_agenda_endeavors_path(@agenda), params: { endeavor_id: @endeavor.id, dated_agenda_section_id: @agenda.default_agenda_section.id }
    end

    item = @agenda.dated_agenda_items.find_by!(endeavor: @endeavor)
    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Car Show", item.title
    assert_equal "Confirm permits", item.summary
    assert_includes item.body.to_s, "Permit history"
  end

  test "duplicate Endeavor is rejected" do
    DatedAgendaItem.create_from_endeavor!(@endeavor, dated_agenda: @agenda, position: 1)
    sign_in_as(@manager)

    assert_no_difference -> { @agenda.dated_agenda_items.count } do
      post admin_dated_agenda_endeavors_path(@agenda), params: { endeavor_id: @endeavor.id, dated_agenda_section_id: @agenda.default_agenda_section.id }
    end

    assert_redirected_to new_admin_dated_agenda_endeavor_path(@agenda, dated_agenda_section_id: @agenda.default_agenda_section.id)
    assert_equal "That Endeavor is already on this agenda.", flash[:alert]
  end

  test "locked agenda rejects Endeavor" do
    @agenda.approve!(@manager)
    sign_in_as(@manager)

    assert_no_difference -> { @agenda.dated_agenda_items.count } do
      post admin_dated_agenda_endeavors_path(@agenda), params: { endeavor_id: @endeavor.id, dated_agenda_section_id: @agenda.default_agenda_section.id }
    end

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before adding an Endeavor.", flash[:alert]
  end

  test "plain member cannot use the picker" do
    sign_in_as(@member)

    get new_admin_dated_agenda_endeavor_path(@agenda, dated_agenda_section_id: @agenda.default_agenda_section.id)

    assert_redirected_to root_path
  end

  test "another organization's Endeavor is not found" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_item = other.endeavors.create!(created_by: @manager, title: "Other business")
    sign_in_as(@manager)

    post admin_dated_agenda_endeavors_path(@agenda), params: { endeavor_id: other_item.id, dated_agenda_section_id: @agenda.default_agenda_section.id }

    assert_response :not_found
  end

  private

  def create_user(label, manage_agendas: false)
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_agendas") if manage_agendas
    user
  end
end
