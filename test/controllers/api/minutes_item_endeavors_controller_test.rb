require "test_helper"

class ApiMinutesItemEndeavorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago)
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @item = @minutes.sections.first.items.create!(title: "Breakfast discussion", behavior_type: "business_item", position: 1,
      body: "The Post agreed to plan a breakfast.", agenda_body: "Discuss a breakfast.")
    @manager = create_user("manage_minutes", "manage_agendas")
    @existing = @organization.endeavors.create!(title: "Flag outreach", created_by: @manager, importance: "standard")
    @path = "/api/meetings/#{@meeting.id}/minutes/items/#{@item.id}/endeavor"
    sign_in_as(@manager)
  end

  test "manual confirmation atomically creates and links while preserving the meeting record" do
    outcome = @item.outcomes.create!(kind: "decision", text: "Organize a breakfast.", disposition: "no_vote", position: 1)
    original = record_snapshot
    assert_difference "Endeavor.count", 1 do
      post @path, params: creation, as: :json
    end
    assert_response :created
    assert_equal original, record_snapshot
    assert_equal outcome.id, response.parsed_body.dig("item", "outcomes", 0, "id")
    assert_equal @item.reload.endeavor_id, response.parsed_body.dig("endeavor", "id")
    assert_equal @item.lock_version, response.parsed_body.dig("item", "lock_version")
    assert_equal "Recruit breakfast volunteers.", @item.endeavor.summary
    assert_equal @manager, @item.endeavor.created_by
    assert_equal "active", @item.endeavor.status
    assert_equal "standard", @item.endeavor.importance
  end

  test "minutes-only users may link and change a confirmed link but may not create" do
    sign_in_as(create_user("manage_minutes"))
    assert_no_difference "Endeavor.count" do
      post @path, params: creation, as: :json
    end
    assert_response :forbidden
    original = record_snapshot
    post @path, params: linking, as: :json
    assert_response :success
    assert_equal @existing.id, response.parsed_body.dig("item", "endeavor_id")
    replacement = @organization.endeavors.create!(title: "Community meals", created_by: @manager, importance: "standard")
    assert_no_difference "Endeavor.count" do
      post @path, params: linking.merge(endeavor_id: replacement.id), as: :json
    end
    assert_response :success
    assert_equal replacement, @item.reload.endeavor
    assert_equal original, record_snapshot
  end

  test "sign-in and minutes authority are required" do
    delete session_path
    post @path, params: creation, as: :json
    assert_response :unauthorized
    sign_in_as(create_user("manage_agendas"))
    post @path, params: creation, as: :json
    assert_response :forbidden
    assert_nil @item.reload.endeavor_id
  end

  test "validation and duplicate identities leave no partial record or link" do
    invalid_payloads = [ creation.except(:endeavor_action), creation.except(:lock_version),
      creation.merge(lock_version: "bad"), creation.merge(title: ""),
      creation.merge(title: " FLAG   outreach "), linking.except(:endeavor_id) ]
    invalid_payloads.each do |payload|
      assert_no_difference "Endeavor.count" do
        post @path, params: payload, as: :json
      end
      assert_response :unprocessable_entity
      assert response.parsed_body["details"].present?
      assert_nil @item.reload.endeavor_id
    end
  end

  test "stale and repeated confirmation cannot create extra records" do
    payload = creation
    @item.update!(title: "Updated discussion")
    assert_no_difference "Endeavor.count" do
      post @path, params: payload, as: :json
    end
    assert_response :conflict
    payload = creation
    post @path, params: payload, as: :json
    assert_response :created
    assert_no_difference "Endeavor.count" do
      post @path, params: payload, as: :json
    end
    assert_response :conflict
    assert_no_difference "Endeavor.count" do
      post @path, params: creation.merge(title: "Another identity"), as: :json
    end
    assert_response :unprocessable_entity
  end

  test "locked official records reject both confirmation modes" do
    %w[attested membership_approved].each do |status|
      @minutes.update_columns(status: status)
      [ creation, linking ].each do |payload|
        assert_no_difference "Endeavor.count" do
          post @path, params: payload, as: :json
        end
        assert_response :unprocessable_entity
        assert_nil @item.reload.endeavor_id
      end
    end
  end

  test "item meeting and organization scopes cannot be crossed" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.endeavors.create!(title: "Foreign work", created_by: @manager, importance: "standard")
    post @path, params: linking.merge(endeavor_id: foreign.id), as: :json
    assert_response :not_found
    other_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 2.days.ago)
    MeetingMinutes.create_from_meeting!(meeting: other_meeting)
    post "/api/meetings/#{other_meeting.id}/minutes/items/#{@item.id}/endeavor", params: creation, as: :json
    assert_response :not_found
    assert_nil @item.reload.endeavor_id
  end

  test "bearer creation records delegation and exact retries replay without duplicate creation" do
    token, secret = AgentAccessToken.issue!(user: @manager, name: "Minutes agent", expires_in: 1.day)
    headers = { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => "confirmed-breakfast" }
    payload = creation
    assert_difference "Endeavor.count", 1 do
      post @path, params: payload, headers: headers, as: :json
    end
    assert_response :created
    original_response = response.parsed_body
    assert_includes response.headers["Cache-Control"], "no-store"
    execution = token.agent_api_executions.find_by!(idempotency_key: "confirmed-breakfast")
    assert_equal @manager, execution.user
    assert_equal @path, execution.request_path
    assert_equal 201, execution.response_status
    assert_no_difference "Endeavor.count" do
      post @path, params: payload, headers: headers, as: :json
    end
    assert_response :created
    assert_equal original_response, response.parsed_body
    post @path, params: payload.merge(title: "Changed intent"), headers: headers, as: :json
    assert_response :conflict
    headers["Idempotency-Key"] = "another-intent"
    post @path, params: payload, headers: headers, as: :json
    assert_response :conflict
    @manager.permission_grants.find_by!(capability: "manage_agendas").destroy!
    post @path, params: creation, headers: headers.merge("Idempotency-Key" => "lost-authority"), as: :json
    assert_response :forbidden
  end

  private

  def create_user(*capabilities)
    person = Person.create!(first_name: "Review", last_name: "Officer")
    user = User.create!(person: person, email_address: "api-review-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end

  def creation
    { endeavor_action: "create", title: "Community breakfast", body: "Recruit breakfast volunteers.", lock_version: @item.reload.lock_version }
  end

  def linking
    { endeavor_action: "link", endeavor_id: @existing.id, lock_version: @item.reload.lock_version }
  end

  def record_snapshot
    @item.reload
    [ @item.title, @item.body.to_plain_text, @item.agenda_body.to_plain_text, @item.minutes_section_id, @item.position,
      @item.source_dated_agenda_item_id, @item.outcomes.pluck(:id, :text, :disposition) ]
  end
end
