require "test_helper"
require_relative "../support/website_publishing_support"

class WebsiteCalendarTest < ActiveSupport::TestCase
  include WebsitePublishingSupport
  setup { setup_publisher }
  teardown { teardown_publisher }

  def policy = WebsitePublishing::CalendarPolicy.new(@organization)
  def feed = WebsitePublishing::Feed.new(@organization.reload, origin: "https://publisher.example.test")
  def events = feed.events(from: "2026-10-01", to: "2026-11-01")[:events]

  def activate(types = %w[member_meeting public_event])
    policy.apply!(actor: @publisher, review_token: policy.preview(types: types)[:review_token])
  end

  test "explicit types and overrides publish independently of attendance and legacy visibility" do
    inferred = event_source(title: "Member meeting", visibility: "public")
    typed = event_source(calendar_category: "public_event", visibility: "members", description: "PRIVATE logistics", attendance: "invited")
    hidden = event_source(calendar_category: "public_event", website_listing: "hide")
    exceptional = event_source(calendar_category: "honor_guard", website_listing: "show", website_description: "Public ceremony")
    assert_empty events
    activate
    assert_equal [ typed.website_public_id, exceptional.website_public_id ].sort, events.pluck("id").sort
    assert_not_includes events.to_json, "PRIVATE"
    assert_equal "invited", feed.event_detail(typed.website_public_id)[:event]["attendance"]
    assert_raises(ActiveRecord::RecordNotFound) { feed.event_detail(inferred.website_public_id) }
    assert_raises(ActiveRecord::RecordNotFound) { feed.event_detail(hidden.website_public_id) }
    inferred.update!(title: "Public event renamed")
    assert_not inferred.website_listed?
  end

  test "formal meetings expose only schedule notice fields and keep document protections" do
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: Time.zone.parse("2026-10-06 19:00"),
      title: "Post membership meeting", calendar_category: "member_meeting", website_description: "Monthly meeting", location_name: "Post hall")
    activate
    notice = feed.event_detail(meeting.website_public_id)[:event]
    assert_equal "Attendance: Post members.\n\nMonthly meeting", notice["description"]
    assert_equal "Post hall", notice["location"]
    assert_equal %w[all_day attendance cancelled category description ends_at ends_on_exclusive id location starts_at starts_on title updated_at].sort, notice.keys.sort
    assert_equal 1, events.size
    meeting.update!(cancelled: true)
    assert feed.event_detail(meeting.website_public_id)[:event]["cancelled"]
    meeting.update!(website_listing: "hide")
    assert_empty events
    assert_raises(ActiveRecord::RecordNotFound) { feed.event_detail(meeting.website_public_id) }
  end

  test "schedule copy cancellation and removal update the public feed immediately" do
    source = event_source(calendar_category: "public_event")
    activate
    source.update!(website_title: "New public title", website_description: "Bring a friend", location: "New place", cancelled: true)
    notice = events.sole
    assert_equal "New public title", notice["title"]
    assert_equal "New place", notice["location"]
    assert notice["cancelled"]
    source.update!(cancelled: false, starts_at: Time.zone.parse("2026-11-03 18:00"))
    assert_empty events
    assert_not feed.event_detail(source.website_public_id)[:event]["cancelled"]
    source.destroy!
    assert_raises(ActiveRecord::RecordNotFound) { feed.event_detail(source.website_public_id) }
    assert WebsiteCalendarChange.exists?(record_type: "CalendarEvent", record_id: source.id, action: "deleted")
  end

  test "website notice edits do not unlock or rewrite an approved meeting document" do
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = @organization.meeting_types.create!(name: "Membership", slug: "membership", position: 1, active: true)
    meeting = create_meeting!(organization: @organization, meeting_body: body, meeting_type: type,
      starts_at: Time.zone.parse("2026-10-06 19:00"), calendar_category: "member_meeting")
    agenda = DatedAgenda.create_from_template!(meeting: meeting)
    agenda.approve!(@publisher)
    heading = agenda.attributes.slice("starts_at", "title", "location_name", "location_address")
    assert_not meeting.update(starts_at: meeting.starts_at + 1.day)
    meeting.reload.update!(website_title: "Membership notice", website_description: "Attendance details only")
    assert_equal heading, agenda.reload.attributes.slice(*heading.keys)
    assert agenda.approved?
  end

  test "all day overlap uses inclusive source end and exclusive feed interval" do
    source = event_source(calendar_category: "public_event", all_day: true,
      starts_at: Time.zone.parse("2026-09-30"), ends_at: Time.zone.parse("2026-10-01").end_of_day)
    activate
    assert_equal "2026-10-02", events.sole["ends_on_exclusive"]
    source.update!(ends_at: Time.zone.parse("2026-09-30").end_of_day)
    assert_empty events
  end

  test "preview requires authority and rejects tampering stale sources and other organizations" do
    source = event_source
    token = policy.preview(types: %w[public_event])[:review_token]
    source.update!(location: "Changed place")
    assert_raises(WebsitePublishing::CalendarPolicy::Conflict) { policy.apply!(actor: @publisher, review_token: token) }
    assert_raises(WebsitePublishing::CalendarPolicy::Conflict) { policy.apply!(actor: @publisher, review_token: "tampered") }
    assert_not @organization.reload.website_calendar_enabled?
    token = policy.preview(types: %w[public_event])[:review_token]
    @publisher.permission_grants.destroy_all
    assert_raises(WebsitePublication::Forbidden) { policy.apply!(actor: @publisher, review_token: token) }
    assert_raises(ArgumentError) { policy.preview(types: %w[invented]) }
  end

  test "preview expires and cannot be reused after policy changes or record creation" do
    token = policy.preview(types: [])[:review_token]
    travel 31.minutes do
      assert_raises(WebsitePublishing::CalendarPolicy::Conflict) { policy.apply!(actor: @publisher, review_token: token) }
    end
    event_source
    assert_raises(WebsitePublishing::CalendarPolicy::Conflict) { policy.apply!(actor: @publisher, review_token: token) }
    fresh = policy.preview(types: [])[:review_token]
    policy.apply!(actor: @publisher, review_token: fresh)
    assert_raises(WebsitePublishing::CalendarPolicy::Conflict) { policy.apply!(actor: @publisher, review_token: fresh) }
    assert WebsiteCalendarChange.exists?(record_type: "Organization", actor_id: @publisher.id, action: "defaults_saved")
  end

  test "activation replaces legacy event snapshots and disables legacy writes without affecting stories" do
    source = event_source(calendar_category: "public_event")
    publication = event_publication(source)
    assert_equal source.website_public_id, publication.public_id
    assert_equal publication.snapshot, events.sole
    introduction = story
    activate
    assert_equal source.website_public_id, events.sole["id"]
    assert_raises(ArgumentError) { publication.publish!(actor: @publisher, version: publication.lock_version, source_version: source.lock_version) }
    assert_raises(ArgumentError) { WebsitePublication.create_draft!(organization: @organization, actor: @publisher, calendar_event: event_source) }
    introduction.withdraw!(actor: @publisher, version: introduction.lock_version)
    assert_equal "withdrawn", introduction.reload.status
  end

  test "records and signed previews cannot cross organizations" do
    event = event_source(website_listing: "show")
    token = policy.preview(types: [])[:review_token]
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "UTC", website_calendar_enabled: true)
    assert_raises(WebsitePublishing::CalendarPolicy::Conflict) { WebsitePublishing::CalendarPolicy.new(other).apply!(actor: @publisher, review_token: token) }
    other_feed = WebsitePublishing::Feed.new(other, origin: "https://publisher.example.test")
    assert_empty other_feed.events(from: "2026-10-01", to: "2026-11-01")[:events]
    assert_raises(ActiveRecord::RecordNotFound) { other_feed.event_detail(event.website_public_id) }
  end
end
