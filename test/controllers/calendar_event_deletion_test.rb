require "test_helper"

class CalendarEventDeletionTest < ActionDispatch::IntegrationTest
  setup do
    @org = Organization.create!(name: "Example Post", unit_type: "american_legion_post")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @manager = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Manager"), email_address: "manager@example.com")
    @manager.permission_grants.create!(capability: "manage_settings")
    @member = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Member"), email_address: "member@example.com")
    @project = @org.endeavors.create!(title: "Festival", created_by: @manager)
    @event = @org.calendar_events.create!(title: "Duplicate event", starts_at: Time.current, visibility: "public", endeavor: @project, created_by: @manager, updated_by: @manager)
  end

  test "HTML deletion requires manager and current lock and retains Endeavor and Meetings" do
    sign_in_as(@member)
    delete calendar_event_path(@event), params: { lock_version: 0 }
    assert CalendarEvent.exists?(@event.id)
    sign_in_as(@manager)
    delete calendar_event_path(@event)
    assert CalendarEvent.exists?(@event.id)
    @event.update!(title: "Changed event")
    delete calendar_event_path(@event), params: { lock_version: 0 }
    assert CalendarEvent.exists?(@event.id)
    before = [ @project.attributes, Meeting.count, MeetingMinutes.count ]
    assert_difference "CalendarEvent.count", -1 do
      delete calendar_event_path(@event), params: { lock_version: @event.lock_version }
      assert_response :see_other
    end
    assert_equal before, [ @project.reload.attributes, Meeting.count, MeetingMinutes.count ]
    assert_empty @org.calendar_events.publicly_visible
  end

  test "API deletion is scoped authorized locked and idempotent" do
    sign_in_as(@member)
    delete "/api/calendar_events/#{@event.id}", params: { lock_version: 0 }, as: :json
    assert_response :forbidden
    token, secret = AgentAccessToken.issue!(user: @manager, name: "Deletion test", expires_in: 1.day)
    headers = { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => "missing-lock" }
    delete "/api/calendar_events/#{@event.id}", headers: headers, as: :json
    assert_response :unprocessable_entity
    @event.update!(title: "Changed event")
    delete "/api/calendar_events/#{@event.id}", params: { lock_version: 0 }, headers: headers.merge("Idempotency-Key" => "stale"), as: :json
    assert_response :conflict
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post")
    other_event = other.calendar_events.create!(title: "Other", starts_at: Time.current, created_by: @manager, updated_by: @manager)
    delete "/api/calendar_events/#{other_event.id}", params: { lock_version: 0 }, headers: headers.merge("Idempotency-Key" => "other"), as: :json
    assert_response :not_found
    assert_difference "CalendarEvent.count", -1 do
      2.times do
        delete "/api/calendar_events/#{@event.id}", params: { lock_version: @event.lock_version }, headers: headers.merge("Idempotency-Key" => "delete"), as: :json
        assert_response :no_content
      end
    end
    assert_equal @manager.id, token.agent_api_executions.last.user_id
    assert Endeavor.exists?(@project.id)
    assert CalendarEvent.exists?(other_event.id)
  end

  test "member and PEC entries are protected in HTML API and model" do
    sign_in_as(@manager)
    [ [ "Membership Meeting", nil ], [ "PEC", nil ], [ "Regular business", "member_meeting" ], [ "Regular business", "officer_meeting" ] ].each do |title, category|
      @event.update!(title: title, calendar_category: category)
      get edit_calendar_event_path(@event)
      assert_select "button", text: "Delete event", count: 0
      assert_not @event.destroy
      delete calendar_event_path(@event), params: { lock_version: @event.lock_version }
      assert CalendarEvent.exists?(@event.id)
      delete "/api/calendar_events/#{@event.id}", params: { lock_version: @event.lock_version }, as: :json
      assert_response :unprocessable_entity
      assert CalendarEvent.exists?(@event.id)
    end
  end

  test "actual Meetings cannot be deleted through calendar event routes" do
    body = @org.meeting_bodies.create!(name: "PEC", slug: "pec")
    meeting = create_meeting!(organization: @org, meeting_body: body, title: "PEC meeting", starts_at: Time.current)
    sign_in_as(@manager)
    before = meeting.attributes
    delete calendar_event_path(meeting.id), params: { lock_version: 0 }
    assert_equal before, meeting.reload.attributes
    delete "/api/calendar_events/#{meeting.id}", params: { lock_version: 0 }, as: :json
    assert_equal before, meeting.reload.attributes
  end

  test "handbook deletion appears only under explicit actions for calendar managers" do
    [ [ @manager, true ], [ @member, false ] ].each do |user, allowed|
      sign_in_as(user)
      get "/api", as: :json
      assert_equal allowed, response.parsed_body["only_when_asked"].any? { |a| a["name"] == "delete_calendar_event" }
      assert_not response.parsed_body["common_actions"].any? { |a| a["name"] == "delete_calendar_event" }
    end
  end
end
