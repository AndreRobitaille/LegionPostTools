require "test_helper"

class EndeavorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @manager = create_user("Manager", capabilities: [ "manage_agendas" ])
    @member = create_user("Member")
    @endeavor = @organization.endeavors.create!(
      meeting_body: @meeting_body,
      created_by: @manager,
      title: "Car Show",
      summary: "Confirm permits",
      importance: "important",
      raise_by_on: 2.weeks.from_now.to_date,
      details: "Permit and volunteer history"
    )
  end

  test "signed out users are redirected" do
    get endeavors_path

    assert_redirected_to new_session_path
  end

  test "signed in members can read Endeavor and continuity" do
    @endeavor.updates.create!(author: @manager, body: "The city received the application.")
    sign_in_as(@member)

    get endeavors_path
    assert_response :success
    assert_select "h1", text: "Endeavors"
    assert_select "a[href=?]", endeavor_path(@endeavor), text: /Car Show/
    assert_select ".endeavor-bucket--necessity"

    get endeavor_path(@endeavor)
    assert_response :success
    assert_select ".continuity", text: /city received the application/
    assert_select "a[href=?]", edit_endeavor_path(@endeavor), count: 0
    assert_select "body", text: /Raise by|Due in|Why it is here/, count: 0
  end

  test "completed Endeavor shows completion instead of overdue planning language" do
    @endeavor.update!(raise_by_on: 1.week.ago.to_date)
    @endeavor.complete!(@manager)
    sign_in_as(@member)

    get endeavors_path

    assert_select "a[href=?]", endeavor_path(@endeavor), text: /Completed.*View details/m
    assert_select "a[href=?]", endeavor_path(@endeavor), text: /Overdue|Raise by|Due in/, count: 0

    get endeavor_path(@endeavor)

    assert_select ".card-head-label", text: "Completion record"
    assert_select ".endeavor-facts", text: /Completed/
    assert_select ".endeavor-facts", text: /Overdue|Why it is here|Current direction/, count: 0
  end

  test "continuity promotes an attested meeting from agenda to minutes" do
    meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    agenda = create_dated_agenda!(
      organization: @organization,
      meeting_body: @meeting_body,
      meeting_type:,
      starts_at: 1.week.ago,
      title: "Membership Meeting"
    )
    DatedAgendaItem.create_from_endeavor!(
      @endeavor,
      position: 1,
      dated_agenda: agenda
    )
    agenda.approve!(@manager)
    agenda.publish!(@manager)
    minutes = MeetingMinutes.create_from_meeting!(meeting: agenda.meeting)
    minutes.update!(status: "attested")
    sign_in_as(@member)

    get endeavor_path(@endeavor)

    assert_select "a[href=?]", meeting_minutes_path(agenda.meeting), text: "Read the attested minutes"
    assert_select "a[href=?]", dated_agenda_path(agenda), count: 0
  end

  test "manager creates Endeavor" do
    sign_in_as(@manager)

    assert_difference -> { @organization.endeavors.count }, 1 do
      post endeavors_path, params: {
        endeavor: {
          title: "Buddy Checks",
          summary: "Call the remaining members",
          meeting_body_id: @meeting_body.id,
          importance: "standard",
          raise_by_on: "2026-09-15",
          details: "Twenty calls remain."
        }
      }
    end

    created = @organization.endeavors.order(:created_at).last
    assert_redirected_to endeavor_path(created)
    assert_equal @manager, created.created_by
    assert_includes created.details.to_s, "Twenty calls remain."
  end

  test "plain member cannot create or edit Endeavor" do
    sign_in_as(@member)

    get new_endeavor_path
    assert_redirected_to root_path

    patch endeavor_path(@endeavor), params: { endeavor: { title: "Changed" } }
    assert_redirected_to root_path
    assert_equal "Car Show", @endeavor.reload.title
  end

  test "create rejects another organization's meeting body" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_body = other.meeting_bodies.create!(name: "Other Membership", slug: "other-membership")
    sign_in_as(@manager)

    post endeavors_path, params: { endeavor: { title: "Wrong body", meeting_body_id: other_body.id, importance: "standard" } }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Meeting body must belong to the same organization/
  end

  test "manager updates and completes then reopens an item" do
    sign_in_as(@manager)

    patch endeavor_path(@endeavor), params: { endeavor: { title: "Annual Car Show", lock_version: @endeavor.lock_version } }
    assert_redirected_to endeavor_path(@endeavor)
    assert_equal "Annual Car Show", @endeavor.reload.title

    patch complete_endeavor_path(@endeavor)
    assert_redirected_to endeavor_path(@endeavor)
    assert @endeavor.reload.completed?
    assert_equal @manager, @endeavor.completed_by

    patch reopen_endeavor_path(@endeavor)
    assert_redirected_to endeavor_path(@endeavor)
    assert @endeavor.reload.active?
  end

  test "stale edit redirects with a useful conflict message" do
    sign_in_as(@manager)
    stale_version = @endeavor.lock_version
    @endeavor.update!(summary: "Changed elsewhere")

    patch endeavor_path(@endeavor), params: { endeavor: { title: "Stale title", lock_version: stale_version } }

    assert_redirected_to endeavor_path(@endeavor)
    assert_equal "This Endeavor changed elsewhere. Review the latest version before editing again.", flash[:alert]
  end

  private

  def create_user(label, capabilities: [])
    person = Person.create!(first_name: "Test", last_name: label)
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
