require "test_helper"
require_relative "../support/website_publishing_support"

class WebsiteCalendarControllerTest < ActionDispatch::IntegrationTest
  include WebsitePublishingSupport

  setup do
    setup_publisher
    Installation.singleton.update!(setup_completed_at: Time.current)
    @manager = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Manager"), email_address: "calendar-manager@example.test")
    @manager.permission_grants.create!(capability: "manage_settings")
    @manager.permission_grants.create!(capability: "manage_agendas")
    @agent, @secret = AgentAccessToken.issue!(user: @publisher, name: "Policy agent", expires_in: 1.day)
    _, @website_secret = WebsiteAccessToken.issue!(organization: @organization, actor: @manager, name: "Website")
  end
  teardown { teardown_publisher }

  def bearer(key = SecureRandom.uuid)
    { "Authorization" => "Bearer #{@secret}", "Idempotency-Key" => key }
  end

  test "defaults require publishing authority in HTML and API" do
    get api_website_calendar_path
    assert_response :unauthorized
    sign_in_as(@manager)
    get admin_website_calendar_path
    assert_redirected_to root_path
    get api_website_calendar_path
    assert_response :forbidden
    post preview_api_website_calendar_path, params: { types: [] }, as: :json
    assert_response :forbidden
    patch api_website_calendar_path, params: { review_token: "bad" }, as: :json
    assert_response :forbidden
    assert_not @organization.reload.website_calendar_enabled?
  end

  test "HTML preview includes concrete visibility and signed activation" do
    event_source(title: "Public gathering", calendar_category: "public_event")
    sign_in_as(@publisher)
    get admin_website_calendar_path
    assert_response :success
    post preview_admin_website_calendar_path, params: { types: %w[public_event] }
    assert_response :success
    assert_select ".website-calendar-preview-row", text: /Public gathering.*Shown/m
    token = css_select('input[name="review_token"]').sole["value"]
    patch admin_website_calendar_path, params: { review_token: token }
    assert_redirected_to admin_website_calendar_path
    assert @organization.reload.website_calendar_enabled?
  end

  test "API policy preview activation replay and provenance" do
    post preview_api_website_calendar_path, params: { types: %w[public_event] }, headers: bearer, as: :json
    assert_response :success
    token = response.parsed_body.dig("website_calendar", "review_token")
    key = SecureRandom.uuid
    2.times do
      patch api_website_calendar_path, params: { review_token: token }, headers: bearer(key), as: :json
      assert_response :success
    end
    assert_equal 1, @organization.reload.website_calendar_version
    audit = WebsiteCalendarChange.find_by!(action: "defaults_saved")
    assert_equal @publisher.id, audit.actor_id
    assert_equal @agent.id, audit.details.dig("delegated_agent", "token_id")
    patch api_website_calendar_path, params: { review_token: token }, headers: bearer, as: :json
    assert_response :conflict
    post preview_api_website_calendar_path, params: { types: [ "inferred" ] }, headers: bearer, as: :json
    assert_response :unprocessable_entity
  end

  test "calendar manager edits event listing through API and feed invalidates old etag" do
    @organization.update!(website_calendar_enabled: true)
    source = event_source(calendar_category: "public_event", description: "Private details")
    headers = { "Authorization" => "Bearer #{@website_secret}" }
    path = "/public/v1/events/#{source.website_public_id}"
    get path, headers: headers
    assert_response :success
    etag = response.headers["ETag"]
    assert_not_includes response.body, "Private details"
    sign_in_as(@manager)
    patch api_calendar_event_path(source), params: { lock_version: source.lock_version, website_title: "New title", website_description: "Public copy", attendance: "invited" }, as: :json
    assert_response :success
    assert_equal "listed", response.parsed_body.dig("calendar_event", "website_publication", "status")
    assert_equal "Public copy", source.reload.website_description
    get path, headers: headers.merge("If-None-Match" => etag)
    assert_response :success
    assert_not_equal etag, response.headers["ETag"]
    assert_includes response.body, "Public copy"
    patch api_calendar_event_path(source), params: { lock_version: source.lock_version, website_listing: "hide" }, as: :json
    assert_response :success
    get path, headers: headers.merge("If-None-Match" => etag)
    assert_response :not_found
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "meeting manager edits listing without gaining policy or document authority" do
    @organization.update!(website_calendar_enabled: true)
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "members")
    sign_in_as(@manager)
    post api_meetings_path, params: { meeting_body_id: body.id, starts_at: "2026-10-06T19:00:00-05:00", location_name: "Post hall", calendar_category: "member_meeting", website_listing: "default", attendance: "members", website_description: "Monthly meeting" }, as: :json
    assert_response :created
    meeting = Meeting.find(response.parsed_body.dig("meeting", "id"))
    assert_nil meeting.minutes
    assert_nil meeting.dated_agenda
    assert response.parsed_body.dig("meeting", "website_calendar", "listed")
    assert_equal @manager.id, WebsiteCalendarChange.where(record_type: "Meeting", record_id: meeting.id).last.actor_id
    patch api_meeting_path(meeting), params: { lock_version: meeting.lock_version, cancelled: true }, as: :json
    assert_response :success
    assert meeting.reload.cancelled?
    patch api_meeting_path(meeting), params: { lock_version: meeting.lock_version, cancelled: "false" }, as: :json
    assert_response :unprocessable_entity
  end

  test "policy activation has session CSRF protection" do
    sign_in_as(@publisher)
    previous = Api::BaseController.allow_forgery_protection
    Api::BaseController.allow_forgery_protection = true
    patch api_website_calendar_path, params: { review_token: "not signed" }, as: :json
    assert_response :unprocessable_entity
    assert_not @organization.reload.website_calendar_enabled?
  ensure
    Api::BaseController.allow_forgery_protection = previous
  end
end
