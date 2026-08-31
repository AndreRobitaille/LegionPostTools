require "test_helper"

class Admin::MeetingMinutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Legion Hall",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(
      organization: @organization,
      meeting_body: @body,
      starts_at: 1.day.ago,
      title: "August Membership"
    )
    @manager = create_user_with("manage_minutes")
  end

  test "minutes managers can create the scaffold and open the workspace" do
    sign_in_as(@manager)

    assert_difference -> { MeetingMinutes.count }, 1 do
      post admin_meeting_minutes_path(@meeting)
    end

    assert_redirected_to admin_meeting_minutes_path(@meeting)
    follow_redirect!
    assert_response :success
    assert_select ".minutes-draft-stamp", text: "Draft minutes"
    assert_select ".minutes-section h3", text: "Meeting record"
    assert_select "a[href='#{new_admin_meeting_transcript_path(@meeting)}']", text: "Add transcript"
  end

  test "internal record viewers may read but not create minutes" do
    viewer = create_user_with("view_internal_records")
    minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    sign_in_as(viewer)

    get admin_meeting_minutes_path(@meeting)
    assert_response :success
    assert_select "a", text: "Add transcript", count: 0

    other_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 2.days.ago)
    post admin_meeting_minutes_path(other_meeting)
    assert_redirected_to root_path
    assert_not other_meeting.reload.minutes
    assert minutes.persisted?
  end

  test "authorized officers can open the current draft as an inline PDF" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    sign_in_as(@manager)
    rendered_minutes = nil
    renderer = lambda do |minutes:|
      rendered_minutes = minutes
      "%PDF-1.7\ndraft minutes"
    end

    with_stubbed_class_method(MeetingMinutesPdf, :render, renderer) do
      get print_admin_meeting_minutes_path(@meeting)
    end

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers.fetch("Content-Disposition"))
    assert_match(/draft-minutes\.pdf/, response.headers.fetch("Content-Disposition"))
    assert_equal minutes, rendered_minutes
  end

  test "unrelated users cannot open the workspace" do
    MeetingMinutes.create_from_meeting!(meeting: @meeting)

    get admin_meeting_minutes_path(@meeting)
    assert_redirected_to new_session_path

    sign_in_as(create_user_with)
    get admin_meeting_minutes_path(@meeting)
    assert_redirected_to root_path
  end

  test "future meetings cannot begin minutes" do
    future = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.from_now)
    sign_in_as(@manager)

    assert_no_difference -> { MeetingMinutes.count } do
      post admin_meeting_minutes_path(future)
    end

    assert_redirected_to admin_meeting_path(future)
    assert_match(/must be in the past/, flash[:alert])
  end

  test "Commander sees the exact-draft approval action and begins one-use confirmation" do
    @manager.permission_grants.create!(capability: "approve_minutes")
    minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    session_record = sign_in_as(@manager)

    get admin_meeting_minutes_path(@meeting)
    assert_response :success
    assert_select "a[href='#{new_admin_meeting_minutes_approval_path(@meeting)}']", text: "Approve exact draft"
    assert_select ".minutes-lifecycle-rail", text: /Commander approval.*Adjutant release.*Membership acceptance/m

    get new_admin_meeting_minutes_approval_path(@meeting)
    assert_response :success
    assert_select "h1", text: "Approve this exact draft"

    assert_difference -> { OfficialActionConfirmation.count }, 1 do
      post admin_meeting_minutes_approval_path(@meeting)
    end
    assert_redirected_to new_official_action_reauthentication_path
    confirmation = OfficialActionConfirmation.last
    assert_equal minutes, confirmation.meeting_minutes
    assert_equal @manager, confirmation.user
    assert_equal session_record, confirmation.session
    assert_equal "approve", confirmation.action
  end

  private

  def create_user_with(*capabilities)
    person = Person.create!(first_name: "Minutes", last_name: SecureRandom.hex(3))
    user = User.create!(person: person, email_address: "minutes-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
