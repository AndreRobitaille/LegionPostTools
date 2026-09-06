require "test_helper"

class ApiCalendarActivitiesApiTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @manager = user("Manager", "manage_settings")
    @member = user("Member")
    @editor = user("Editor", "manage_agendas")
    @project = @organization.endeavors.create!(title: "Festival", created_by: @manager, due_on: Date.new(2026, 9, 19))
    @task = @project.tasks.create!(title: "Confirm power", due_on: Date.new(2026, 9, 10), created_by: @manager, updated_by: @manager)
    @private_event = @organization.calendar_events.create!(title: "Private planning", description: "Private notes", location: "Private home", starts_at: Time.zone.local(2026, 9, 8, 17, 30), endeavor: @project, created_by: @manager, updated_by: @manager)
    @public_event = @organization.calendar_events.create!(title: "Festival day", starts_at: Time.zone.local(2026, 9, 19), all_day: true, visibility: "public", endeavor: @project, created_by: @manager, updated_by: @manager)
  end

  test "all calendar and task reads require authentication including public preview" do
    [ "/api/calendar?view=public", "/api/calendar_events?preview=public", "/api/calendar_events/#{@public_event.id}?preview=public", tasks_path, task_path ].each do |path|
      get path, as: :json
      assert_response :unauthorized
    end
  end

  test "member calendar includes schedules and opt-in deadlines without internal meeting documents" do
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: @organization, meeting_body: body, title: "Membership", starts_at: Time.zone.local(2026, 9, 1, 18))
    sign_in_as(@member)
    get "/api/calendar", params: { start_date: "2026-09-01" }, as: :json
    assert_response :success
    entries = response.parsed_body.dig("calendar", "entries")
    assert_equal 3, entries.size
    assert_equal %w[id location_address location_name starts_at title type], entries.find { |e| e["type"] == "meeting" }.keys.sort
    assert_equal meeting.id, entries.find { |e| e["type"] == "meeting" }["id"]
    get "/api/calendar", params: { start_date: "2026-09-01", view: "deadlines" }, as: :json
    assert_equal 2, response.parsed_body.dig("calendar", "entries").count { |e| e["type"] == "deadline" }
    @task.set_completion(true, user: @manager)
    @task.save!
    @project.complete!(@manager)
    get "/api/calendar", params: { start_date: "2026-09-01", view: "deadlines" }, as: :json
    assert_equal 0, response.parsed_body.dig("calendar", "entries").count { |e| e["type"] == "deadline" }
  end

  test "public projection hides private rows and internal fields in every route" do
    sign_in_as(@member)
    get "/api/calendar", params: { start_date: "2026-09-01", view: "public" }, as: :json
    entries = response.parsed_body.dig("calendar", "entries")
    assert_equal [ @public_event.id ], entries.map { |e| e["id"] }
    assert_equal (@public_event.public_calendar_attributes.keys + [ "type" ]).sort, entries.first.keys.sort
    get "/api/calendar_events", params: { preview: "public" }, as: :json
    assert_equal [ @public_event.id ], response.parsed_body["calendar_events"].map { |e| e["id"] }
    assert_equal @public_event.public_calendar_attributes.keys.sort, response.parsed_body["calendar_events"].first.keys.sort
    get "/api/calendar_events/#{@public_event.id}", params: { preview: "public" }, as: :json
    assert_equal @public_event.public_calendar_attributes.keys.sort, response.parsed_body["calendar_event"].keys.sort
    assert_no_match(/Private home|Private notes|endeavor_id|created_by_id|lock_version/, response.body)
    get "/api/calendar_events/#{@private_event.id}", params: { preview: "public" }, as: :json
    assert_response :not_found
    get "/api/calendar_events", params: { preview: "public", endeavor_id: @project.id }, as: :json
    assert_response :unprocessable_entity
  end

  test "members cannot mutate and manual agenda grants do not confer calendar management" do
    [ @member, @editor ].each do |caller|
      sign_in_as(caller)
      assert_no_difference "CalendarEvent.count" do
        post "/api/calendar_events", params: event_input, as: :json
        assert_response :forbidden
      end
      patch "/api/calendar_events/#{@private_event.id}", params: { cancelled: true, lock_version: 0 }, as: :json
      assert_response :forbidden
      assert_not @private_event.reload.cancelled?
    end
    sign_in_as(@member)
    post tasks_path, params: { title: "Do work" }, as: :json
    assert_response :forbidden
    patch task_path, params: { completed: true, lock_version: 0 }, as: :json
    assert_response :forbidden
    patch "/api/endeavors/#{@project.id}", params: { due_on: nil, lock_version: 0 }, as: :json
    assert_response :forbidden
  end

  test "current office-derived calendar authority is rechecked and reflected in handbook" do
    %w[approve_minutes attest_minutes].each do |capability|
      office = @organization.position_titles.create!(name: capability, display_order: 1)
      office.position_capability_grants.create!(capability: capability)
      assignment = office.position_assignments.create!(person: @member.person, starts_on: Date.current - 2.days)
      sign_in_as(@member)
      get "/api", as: :json
      assert response.parsed_body.dig("caller", "calendar_management")
      assert response.parsed_body["common_actions"].any? { |a| a["name"] == "create_calendar_event" && a["permission"] == "calendar_management" }
      post "/api/calendar_events", params: event_input, as: :json
      assert_response :created
      assignment.update!(ends_on: Date.yesterday)
      post "/api/calendar_events", params: event_input, as: :json
      assert_response :forbidden
      get "/api", as: :json
      assert_not response.parsed_body["common_actions"].any? { |a| a["name"] == "create_calendar_event" }
    end
  end

  test "handbook documents activity fields and exposes exactly the callers write authority" do
    [ [ @member, false ], [ @editor, true ] ].each do |caller, can_edit|
      sign_in_as(caller)
      get "/api", as: :json
      handbook = response.parsed_body
      actions = handbook["common_actions"].map { |a| a["name"] }
      assert_includes actions, "read_calendar"
      assert_includes actions, "list_endeavor_tasks"
      assert_equal can_edit, actions.include?("update_endeavor_task")
      assert_not_includes actions, "create_calendar_event"
      assert handbook["activity_fields"].any? { |field| field["name"] == "public_preview" }
      get "/api", headers: { "Accept" => "text/markdown" }
      assert_includes response.body, "Calendar and Endeavor activity fields"
      assert_includes response.body, "lock_version"
    end
  end

  test "date-only input uses local inclusive dates across daylight saving changes" do
    sign_in_as(@manager)
    Time.use_zone("America/Chicago") do
      post "/api/calendar_events", params: { title: "Date only", all_day: true, starts_at: "2026-10-31", ends_at: "2026-11-01" }, as: :json
      assert_response :created
      event = CalendarEvent.find(response.parsed_body.dig("calendar_event", "id"))
      assert_equal Time.zone.local(2026, 10, 31), event.starts_at
      assert_equal Date.new(2026, 11, 1), event.ends_at.to_date
      assert_equal 23, event.ends_at.hour
      assert_equal(-6.hours, event.ends_at.utc_offset)
    end
  end

  test "events support dates, omitted end, updates, cancellation and stale locks" do
    sign_in_as(@manager)
    post "/api/calendar_events", params: event_input.merge(endeavor_id: @project.id), as: :json
    assert_response :created
    event = CalendarEvent.find(response.parsed_body.dig("calendar_event", "id"))
    assert_nil event.ends_at
    assert_equal @manager.id, event.created_by_id
    patch "/api/calendar_events/#{event.id}", params: { cancelled: true, lock_version: 0 }, as: :json
    assert_response :success
    assert event.reload.cancelled?
    patch "/api/calendar_events/#{event.id}", params: { cancelled: false, lock_version: 0 }, as: :json
    assert_response :conflict
    patch "/api/calendar_events/#{event.id}", params: { lock_version: event.lock_version, cancelled: false, all_day: true, starts_at: "2026-09-08", ends_at: "2026-09-09", endeavor_id: nil }, as: :json
    assert_response :success
    assert_nil event.reload.endeavor_id
    assert_equal Date.new(2026, 9, 9), event.ends_at.to_date
    assert_equal 23, event.ends_at.hour
    assert_equal 0, event.starts_at.hour
    assert_not event.cancelled?
    patch "/api/calendar_events/#{event.id}", params: { title: "No lock" }, as: :json
    assert_response :unprocessable_entity
    patch "/api/calendar_events/#{event.id}", params: { lock_version: event.lock_version, all_day: false, starts_at: "2026-09-08T17:30:00-05:00" }, as: :json
    assert_response :unprocessable_entity
  end

  test "invalid dates, offsets, booleans, and end order are rejected without writes" do
    sign_in_as(@manager)
    [ { starts_at: "2026-02-30T10:00:00-06:00" }, { starts_at: "2026-09-08T17:30:00" }, { all_day: true, starts_at: "2026-02-30" }, { all_day: "false" }, { cancelled: "yes" }, { ends_at: "2026-09-07T10:00:00-05:00" } ].each do |bad|
      assert_no_difference "CalendarEvent.count" do
        post "/api/calendar_events", params: event_input.merge(bad), as: :json
        assert_response :unprocessable_entity
      end
    end
    [ { start_date: "bad" }, { start_date: "" }, { view: "typo" }, { limit: 501 }, { offset: -1 } ].each do |bad|
      get "/api/calendar", params: bad, as: :json
      assert_response :unprocessable_entity
    end
  end

  test "event and task histories are paginated and include completed or cancelled records" do
    @private_event.update!(cancelled: true, starts_at: 2.years.ago)
    @task.set_completion(true, user: @manager)
    @task.save!
    sign_in_as(@member)
    get "/api/calendar_events", params: { endeavor_id: @project.id, limit: 1 }, as: :json
    assert_equal @private_event.id, response.parsed_body["calendar_events"].first["id"]
    assert_equal true, response.parsed_body.dig("pagination", "truncated")
    get "/api/calendar_events", params: { endeavor_id: @project.id, limit: 1, offset: 1 }, as: :json
    assert_equal @public_event.id, response.parsed_body["calendar_events"].first["id"]
    get tasks_path, params: { status: "completed" }, as: :json
    assert_equal [ @task.id ], response.parsed_body["tasks"].map { |t| t["id"] }
    get task_path, as: :json
    assert_equal true, response.parsed_body.dig("task", "completed")
  end

  test "task creation and completion preserve dates and actor provenance with safe reopening" do
    sign_in_as(@editor)
    post tasks_path, params: { title: "Recruit helpers", due_on: nil }, as: :json
    assert_response :created
    created = EndeavorTask.find(response.parsed_body.dig("task", "id"))
    assert_nil created.due_on
    assert_equal @editor.id, created.created_by_id
    patch task_path, params: { due_on: "2026-09-11", completed: true, lock_version: 0 }, as: :json
    assert_response :success
    completed_at = @task.reload.completed_at
    assert_equal @editor.id, @task.completed_by_id
    patch task_path, params: { completed: true, lock_version: @task.lock_version }, as: :json
    assert_response :success
    assert_equal completed_at, @task.reload.completed_at
    patch task_path, params: { completed: false, lock_version: @task.lock_version, due_on: nil }, as: :json
    assert_response :success
    assert_nil @task.reload.completed_at
    assert_nil @task.completed_by_id
    assert_nil @task.due_on
    patch task_path, params: { completed: true, lock_version: 0 }, as: :json
    assert_response :conflict
    assert_not @task.reload.completed?
    patch task_path, params: { completed: "false", lock_version: @task.lock_version }, as: :json
    assert_response :unprocessable_entity
    post tasks_path, params: { title: "Bad date", due_on: "2026-09-31" }, as: :json
    assert_response :unprocessable_entity
  end

  test "organization and parent scoping prevent reads links and writes outside the scope" do
    other_org = Organization.create!(name: "Other Post", unit_type: "american_legion_post")
    other_project = other_org.endeavors.create!(title: "Other", created_by: @manager)
    other_event = other_org.calendar_events.create!(title: "Other", starts_at: Time.current, created_by: @manager, updated_by: @manager)
    sign_in_as(@manager)
    get "/api/calendar_events/#{other_event.id}", as: :json
    assert_response :not_found
    post "/api/calendar_events", params: event_input.merge(endeavor_id: other_project.id), as: :json
    assert_response :not_found
    get "/api/endeavors/#{other_project.id}/tasks", as: :json
    assert_response :not_found
    second = @organization.endeavors.create!(title: "Second", created_by: @manager)
    patch "/api/endeavors/#{second.id}/tasks/#{@task.id}", params: { completed: true, lock_version: 0 }, as: :json
    assert_response :not_found
  end

  test "project update supports canonical dates alias precedence and stale locks" do
    sign_in_as(@editor)
    get "/api/endeavors/#{@project.id}", as: :json
    assert_equal tasks_path, response.parsed_body.dig("endeavor", "tasks_path")
    assert_equal "/api/calendar_events?endeavor_id=#{@project.id}", response.parsed_body.dig("endeavor", "calendar_events_path")
    patch "/api/endeavors/#{@project.id}", params: { due_on: "2026-09-20", raise_by_on: "2026-09-21", lock_version: 0 }, as: :json
    assert_response :success
    assert_equal "2026-09-20", response.parsed_body.dig("endeavor", "raise_by_on")
    patch "/api/endeavors/#{@project.id}", params: { due_on: nil, lock_version: 0 }, as: :json
    assert_response :conflict
    patch "/api/endeavors/#{@project.id}", params: { raise_by_on: nil, lock_version: @project.reload.lock_version }, as: :json
    assert_response :success
    assert_nil @project.reload.due_on
  end

  test "bearer mutations require idempotency and replay without duplicate creation" do
    token, plaintext = AgentAccessToken.issue!(user: @manager, name: "API test", expires_in: 1.day)
    headers = { "Authorization" => "Bearer #{plaintext}" }
    post "/api/calendar_events", params: event_input, headers: headers, as: :json
    assert_response :unprocessable_entity
    headers["Idempotency-Key"] = "new-event"
    assert_difference "CalendarEvent.count", 1 do
      2.times do
        post "/api/calendar_events", params: event_input, headers: headers, as: :json
        assert_response :created
        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
    headers["Idempotency-Key"] = "new-task"
    assert_difference "EndeavorTask.count", 1 do
      2.times { post tasks_path, params: { title: "Arrange supplies" }, headers: headers, as: :json }
    end
    assert_equal @manager.id, token.agent_api_executions.last.user_id
    @manager.permission_grants.destroy_all
    headers["Idempotency-Key"] = "no-longer-allowed"
    post "/api/calendar_events", params: event_input, headers: headers, as: :json
    assert_response :forbidden
  end

  test "session writes enforce csrf when protection is enabled" do
    sign_in_as(@manager)
    previous = Api::BaseController.allow_forgery_protection
    Api::BaseController.allow_forgery_protection = true
    post "/api/calendar_events", params: event_input, as: :json
    assert_response :unprocessable_entity
    get "/api", as: :json
    csrf = response.parsed_body.fetch("csrf_token")
    post "/api/calendar_events", params: event_input, headers: { "X-CSRF-Token" => csrf }, as: :json
    assert_response :created
  ensure
    Api::BaseController.allow_forgery_protection = previous
  end

  private

  def user(name, capability = nil)
    record = User.create!(person: Person.create!(first_name: name, last_name: "Example"), email_address: "#{name.downcase}@example.com")
    record.permission_grants.create!(capability: capability) if capability
    record
  end

  def tasks_path = "/api/endeavors/#{@project.id}/tasks"
  def task_path = "#{tasks_path}/#{@task.id}"
  def event_input = { title: "Volunteer planning", starts_at: "2026-09-08T17:30:00-05:00" }
end
