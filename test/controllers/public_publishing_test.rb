require "test_helper"
require_relative "../support/website_publishing_support"

class PublicPublishingTest < ActionDispatch::IntegrationTest
  include WebsitePublishingSupport
  setup { setup_publisher }
  teardown { teardown_publisher }

  test "empty collections are complete anonymous and conditional metadata is current" do
    get "/public/v1/featured_members"
    assert_response :success
    assert_equal({ "schema_version" => 1, "complete" => true, "members" => [] }, response.parsed_body)
    assert_equal %w[max-age=300 must-revalidate public], response.headers["Cache-Control"].split(", ").sort
    assert_equal "0", response.headers["Age"]
    assert response.headers["Date"]
    etag = response.headers["ETag"]
    get "/public/v1/featured_members", headers: { "If-None-Match" => etag }
    assert_response :not_modified
    assert_equal etag, response.headers["ETag"]
    assert_equal "0", response.headers["Age"]
    assert response.headers["Date"]
    head "/public/v1/featured_members"
    assert_response :success
    assert_empty response.body
    get "/public/v1/events", params: { from: "2026-10-01", to: "2026-11-01" }
    assert_response :success
    assert_equal [], response.parsed_body["events"]
    assert_equal "America/Chicago", response.parsed_body["timezone"]
  end

  test "rotation edits replacement withdrawal and consent are reflected even on conditional requests" do
    record = story
    feature(record)
    get "/public/v1/featured_members"
    collection_etag = response.headers["ETag"]
    member = response.parsed_body["members"].first
    portrait_path = URI(member["portrait"]["variants"].first["url"]).path
    get portrait_path
    assert_response :success
    assert_equal "image/webp", response.media_type
    image_etag = response.headers["ETag"]
    feature
    get "/public/v1/featured_members", headers: { "If-None-Match" => collection_etag }
    assert_response :success
    assert_empty response.parsed_body["members"]
    get "/public/v1/member_stories/#{record.public_id}"
    assert_response :success
    record.reload.edit_draft!(actor: @publisher, version: record.lock_version, attributes: {}, portrait: image_upload(190))
    get portrait_path, headers: { "If-None-Match" => image_etag }
    assert_response :not_modified
    record.confirm_consent!(actor: @publisher, version: record.lock_version, note: "Replacement approved")
    record.publish!(actor: @publisher, version: record.lock_version)
    get portrait_path, headers: { "If-None-Match" => image_etag }
    assert_response :not_found
    assert_equal "no-store", response.headers["Cache-Control"]
    get "/public/v1/member_stories/#{record.public_id}"
    story_etag = response.headers["ETag"]
    new_path = URI(response.parsed_body["member"]["portrait"]["variants"].first["url"]).path
    record.withdraw!(actor: @publisher, version: record.lock_version, revoke_consent: true)
    get "/public/v1/member_stories/#{record.public_id}", headers: { "If-None-Match" => story_etag }
    assert_response :not_found
    get new_path
    assert_response :not_found
  end

  test "events use exact overlap boundaries point ends all day DST and stable ordering" do
    zone = @organization.calendar_time_zone
    first = zone.local(2026, 11, 1)
    last = zone.local(2026, 11, 2)
    excluded = event_publication(event_source(starts_at: first - 1.hour, ends_at: first))
    point = event_publication(event_source(starts_at: first, ends_at: first))
    unknown = event_publication(event_source(starts_at: first, ends_at: nil))
    day = event_publication(event_source(all_day: true, starts_at: first, ends_at: nil, cancelled: true))
    multi = event_publication(event_source(all_day: true, starts_at: first - 1.day, ends_at: first.end_of_day))
    late = event_publication(event_source(starts_at: last - 1.minute))
    event_publication(event_source(starts_at: last))
    get "/public/v1/events", params: { from: "2026-11-01", to: "2026-11-02" }
    assert_response :success
    records = response.parsed_body["events"]
    assert_equal [ point, unknown, day, multi, late ].map(&:public_id).sort, records.map { |row| row["id"] }.sort
    assert_equal multi.public_id, records.first["id"]
    assert_equal [ point, unknown, day ].map(&:public_id).sort, records[1..3].map { |row| row["id"] }
    assert_equal late.public_id, records.last["id"]
    assert_equal "2026-11-02", records.first["ends_on_exclusive"]
    assert_includes CalendarEvent.overlapping(first, last), excluded.calendar_event
  end

  test "moves cancellation removals invalidate validators and never leak private parents" do
    private_project = @organization.endeavors.create!(title: "PRIVATE PROJECT", details: "PRIVATE NOTES", created_by: @publisher)
    record = event_publication(event_source(endeavor: private_project))
    get "/public/v1/events", params: { from: "2026-10-01", to: "2026-11-01" }
    etag = response.headers["ETag"]
    assert_not_includes response.body, "PRIVATE"
    source = record.calendar_event
    source.update!(starts_at: Time.zone.local(2026, 12, 1), cancelled: true)
    get "/public/v1/events", params: { from: "2026-10-01", to: "2026-11-01" }, headers: { "If-None-Match" => etag }
    assert_response :success
    assert response.parsed_body["events"].first["cancelled"]
    record.reload.publish!(actor: @publisher, version: record.lock_version, source_version: source.lock_version)
    get "/public/v1/events", params: { from: "2026-10-01", to: "2026-11-01" }
    assert_empty response.parsed_body["events"]
    get "/public/v1/events/#{record.public_id}"
    assert_response :success
    etag = response.headers["ETag"]
    source.update!(visibility: "members")
    get "/public/v1/events/#{record.public_id}", headers: { "If-None-Match" => etag }
    assert_response :not_found
  end

  test "invalid bounds methods unknown identities and outage have safe no-store errors" do
    [ {}, { from: "2026-02-30", to: "2026-03-02" }, { from: "2026-01-01", to: "2026-04-05" }, { from: "2026-01-01", to: "2026-01-01" } ].each do |bounds|
      get "/public/v1/events", params: bounds
      assert_response :bad_request
      assert_equal "no-store", response.headers["Cache-Control"]
    end
    post "/public/v1/events"
    assert_response :method_not_allowed
    assert_equal "GET, HEAD", response.headers["Allow"]
    get "/public/v1/events/unknown"
    assert_response :not_found
    assert_equal({ "schema_version" => 1, "error" => { "code" => "not_found", "message" => "Not found" } }, response.parsed_body)
    get "/public/v1/featured_members"
    etag = response.headers["ETag"]
    ENV["PUBLIC_PUBLISHER_UNAVAILABLE"] = "1"
    get "/public/v1/featured_members", headers: { "If-None-Match" => etag }
    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil response.headers["ETag"]
    assert_equal "60", response.headers["Retry-After"]
  ensure
    ENV.delete("PUBLIC_PUBLISHER_UNAVAILABLE")
  end
  test "throttled requests return a no-store 429 with retry advice" do
    240.times { get "/public/v1/featured_members" }
    assert_response :success
    get "/public/v1/featured_members"
    assert_response :too_many_requests
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "60", response.headers["Retry-After"]
    assert_equal "rate_limited", response.parsed_body.dig("error", "code")
  end

  test "93 day interval is complete and spring DST uses local midnight" do
    get "/public/v1/events", params: { from: "2026-01-01", to: "2026-04-04" }
    assert_response :success
    zone = @organization.calendar_time_zone
    inside = event_publication(event_source(starts_at: zone.local(2026, 3, 8, 23, 30)))
    event_publication(event_source(starts_at: zone.local(2026, 3, 9)))
    get "/public/v1/events", params: { from: "2026-03-08", to: "2026-03-09" }
    assert_response :success
    assert_equal [ inside.public_id ], response.parsed_body["events"].map { |row| row["id"] }
  end
end
