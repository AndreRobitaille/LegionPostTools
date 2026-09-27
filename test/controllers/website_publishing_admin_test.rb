require "test_helper"
require_relative "../support/website_publishing_support"

class WebsitePublishingAdminTest < ActionDispatch::IntegrationTest
  include WebsitePublishingSupport
  setup do
    setup_publisher
    Installation.singleton.update!(setup_completed_at: Time.current)
    @manager = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Manager"), email_address: "manager@example.test")
    @manager.permission_grants.create!(capability: "manage_settings")
  end
  teardown { teardown_publisher }

  test "workspace requires explicit permission and stale review is rejected" do
    sign_in_as(@manager)
    get "/admin/website_publications"
    assert_response :redirect
    sign_in_as(@publisher)
    record = story
    get "/admin/website_publications"
    assert_response :success
    get edit_admin_website_publication_path(record)
    assert_response :success
    assert_select "h2", text: "Working draft"
    assert_select "h2", text: "Currently published"
    assert_equal "no-store", response.headers["Cache-Control"]
    post publish_admin_website_publication_path(record), params: { version: record.lock_version - 1 }
    assert_response :conflict
    @publisher.permission_grants.delete_all
    post withdraw_admin_website_publication_path(record), params: { version: record.lock_version }
    assert_response :redirect
    assert record.reload.published?
  end

  test "draft consent and feature HTML forms publish and rotate synthetic content" do
    sign_in_as(@publisher)
    record = story(publish: false)
    post publish_admin_website_publication_path(record), params: { version: record.lock_version }
    assert_response :redirect
    assert record.reload.published?
    post feature_admin_website_publications_path, params: { ids: [ record.public_id ], versions: { record.id.to_s => record.lock_version.to_s } }
    assert_response :redirect
    assert_equal 1, record.reload.featured_position
    post withdraw_admin_website_publication_path(record), params: { version: record.lock_version, revoke_consent: "1" }
    assert_response :redirect
    assert_equal "withdrawn", record.reload.status
    assert_not record.consent
  end

  test "HTML calendar edits cancel restrict and delete public snapshots" do
    sign_in_as(@manager)
    [ { cancelled: "1" }, { visibility: "members" }, { calendar_category: "planning_meeting" }, { website_designation: "internal" } ].each do |changes|
      record = event_publication
      source = record.calendar_event
      patch calendar_event_path(source), params: { calendar_event: { lock_version: source.lock_version, starts_at_date: "03 OCT 2026", starts_at_time: "18:00", **changes } }
      assert_response :redirect
      record.reload
      if changes.key?(:cancelled)
        assert record.snapshot["cancelled"]
      else
        assert_equal "withdrawn", record.status
      end
      assert_equal @manager.id, record.publication_events.order(:id).last.actor_id
    end
    record = event_publication
    source = record.calendar_event
    delete calendar_event_path(source), params: { lock_version: source.lock_version }
    assert_response :redirect
    assert_nil record.reload.calendar_event_id
    assert_equal "withdrawn", record.status
  end

  test "bearer API applies the same restrictions and cannot approve eligibility" do
    token, secret = AgentAccessToken.issue!(user: @manager, name: "Synthetic calendar", expires_in: 1.day)
    [ { cancelled: true }, { visibility: "members" }, { calendar_category: "honor_guard" }, { website_designation: "internal" } ].each do |changes|
      record = event_publication
      source = record.calendar_event
      patch "/api/calendar_events/#{source.id}", params: { lock_version: source.lock_version, **changes }, headers: { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => SecureRandom.uuid }, as: :json
      assert_response :success
      record.reload
      if changes.key?(:cancelled)
        assert record.snapshot["cancelled"]
      else
        assert_equal "withdrawn", record.status
      end
      assert_equal @manager.id, record.publication_events.order(:id).last.actor_id
    end
    record = event_publication
    source = record.calendar_event
    patch "/api/calendar_events/#{source.id}", params: { lock_version: source.lock_version, website_designation: "public_eligible" }, headers: { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => SecureRandom.uuid }, as: :json
    assert_response :unprocessable_entity
    delete "/api/calendar_events/#{source.id}", params: { lock_version: source.lock_version }, headers: { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => SecureRandom.uuid }, as: :json
    assert_response :no_content
    assert_nil record.reload.calendar_event_id
    assert_equal "withdrawn", record.status
  end
end
