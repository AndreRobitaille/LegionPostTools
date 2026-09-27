require "test_helper"
require_relative "../support/website_publishing_support"

class WebsitePublicationTest < ActiveSupport::TestCase
  include WebsitePublishingSupport
  setup { setup_publisher }
  teardown { teardown_publisher }

  test "technical admin is not a publisher and office grants work without calendar authority" do
    @publisher.permission_grants.delete_all
    @publisher.permission_grants.create!(capability: "manage_settings")
    assert_not @publisher.can?("publish_public_content")
    assert_raises(WebsitePublication::Forbidden) { story }
    @publisher.permission_grants.delete_all
    position = @organization.position_titles.create!(name: "Website editor", display_order: 1)
    position.position_capability_grants.create!(capability: "publish_public_content")
    position.position_assignments.create!(person: @publisher.person, starts_on: Date.current)
    assert @publisher.can?("publish_public_content")
    assert_not @publisher.can_manage_calendar?
    assert event_publication.published?
  end

  test "draft changes leave snapshot unchanged and need renewed consent" do
    record = story
    original = record.snapshot.deep_dup
    record.edit_draft!(actor: @publisher, version: record.lock_version, attributes: { story: "Revised public story" })
    assert_equal original, record.snapshot
    assert_not record.consent_covers_draft?
    assert_raises(ArgumentError) { record.publish!(actor: @publisher, version: record.lock_version) }
    record.confirm_consent!(actor: @publisher, version: record.lock_version, note: "Revised text approved")
    record.publish!(actor: @publisher, version: record.lock_version)
    assert_equal "Revised public story", record.snapshot["story"]
    assert_equal original["portrait_revision"], record.snapshot["portrait_revision"]
    assert_equal 2, record.publication_events.where(action: "published").count
  end

  test "stale reviews cannot undo consent revocation or withdrawal and republishing never restores selection" do
    record = story
    feature(record)
    version = record.lock_version
    record.withdraw!(actor: @publisher, version: version, revoke_consent: true)
    assert_nil record.featured_position
    assert_raises(WebsitePublication::Conflict) { record.publish!(actor: @publisher, version: version) }
    record.confirm_consent!(actor: @publisher, version: record.lock_version, note: "Renewed permission")
    record.publish!(actor: @publisher, version: record.lock_version)
    assert_nil record.featured_position
    record.withdraw!(actor: @publisher, version: record.lock_version)
    assert_raises(WebsitePublication::Conflict) { record.publish!(actor: @publisher, version: version) }
  end

  test "featured order is limited and rotating preserves detail" do
    records = 4.times.map { story }
    feature(*records.take(3))
    assert_raises(ArgumentError) { feature(*records) }
    feature(records.last, records.first)
    assert records[1].reload.published?
    assert_nil records[1].featured_position
    assert_equal 1, records.last.featured_position
  end

  test "calendar changes are pending cancellation is sticky and old reviews conflict" do
    record = event_publication
    source = record.calendar_event
    original = record.snapshot.deep_dup
    old_version = source.lock_version
    source.update!(location: "New location", title: "Unreviewed text", cancelled: true)
    record.reload
    assert record.snapshot["cancelled"]
    assert_nil record.snapshot["location"]
    assert_equal original["title"], record.snapshot["title"]
    assert_raises(WebsitePublication::Conflict) { record.publish!(actor: @publisher, version: record.lock_version, source_version: old_version) }
    source.update!(cancelled: false)
    assert record.reload.snapshot["cancelled"]
    record.publish!(actor: @publisher, version: record.lock_version, source_version: source.lock_version)
    assert_not record.snapshot["cancelled"]
    assert_equal "New location", record.snapshot["location"]
    assert_equal original["title"], record.snapshot["title"]
  end

  test "private internal and deletion restrictions retain tombstones and history" do
    record = event_publication
    source = record.calendar_event
    version = record.lock_version
    source.update!(visibility: "members")
    source.update!(visibility: "public")
    assert_equal "withdrawn", record.reload.status
    assert_raises(WebsitePublication::Conflict) { record.publish!(actor: @publisher, version: version, source_version: source.lock_version) }
    record.publish!(actor: @publisher, version: record.lock_version, source_version: source.lock_version)
    source.update!(calendar_category: "honor_guard")
    source.update!(calendar_category: "other")
    assert_equal "internal", source.website_designation
    assert_equal "withdrawn", record.reload.status
    assert_raises(ArgumentError) { record.publish!(actor: @publisher, version: record.lock_version, source_version: source.lock_version) }
    record.approve_eligibility!(actor: @publisher, version: record.lock_version, source_version: source.lock_version, reason: "Classification corrected")
    assert_equal "withdrawn", record.status
    source.reload.destroy!
    assert_nil record.reload.calendar_event_id
    assert_equal source.id, record.original_calendar_event_id
    assert record.publication_events.exists?(action: "source_deleted")
    assert_raises(ArgumentError) { record.publish!(actor: @publisher, version: record.lock_version, source_version: source.lock_version) }
  end

  test "title warning survives other override and internal stored categories block eligibility" do
    source = event_source(title: "PEC meeting", calendar_category: "other")
    record = WebsitePublication.create_draft!(organization: @organization, actor: @publisher, calendar_event: source)
    assert_equal "officer_meeting", record.title_flag
    assert_raises(ArgumentError) { record.approve_eligibility!(actor: @publisher, version: record.lock_version, source_version: source.lock_version, reason: "No disposition") }
    source.update!(calendar_category: "officer_meeting")
    assert_equal "internal", source.website_designation
    assert_raises(ArgumentError) { record.approve_eligibility!(actor: @publisher, version: record.reload.lock_version, source_version: source.lock_version, reason: "Override", resolve_flags: true) }
  end

  test "source deletion protection and permanent identity are preserved" do
    source = event_source(title: "Member meeting")
    record = WebsitePublication.create_draft!(organization: @organization, actor: @publisher, calendar_event: source)
    assert_raises(ActiveRecord::RecordNotDestroyed) { source.destroy! }
    assert_equal source.id, record.reload.calendar_event_id
    assert_not record.update(calendar_event: event_source)
  end

  test "portraits are fixed size metadata stripped and invalid content rejected" do
    record = story
    image = record.portraits.first
    { small: [ 320, 400 ], large: [ 640, 800 ] }.each do |size, dimensions|
      decoded = Vips::Image.new_from_buffer(image.public_send(size), "")
      assert_equal dimensions, [ decoded.width, decoded.height ]
      assert_not decoded.get_fields.any? { |field| field.start_with?("exif", "xmp", "iptc") }
    end
    assert_raises(ArgumentError) { record.edit_draft!(actor: @publisher, version: record.lock_version, attributes: {}, portrait: StringIO.new("not an image")) }
  end
  test "legacy visibility alone never publishes and eligibility needs a reviewed source version" do
    source = event_source
    assert_equal "unreviewed", source.website_designation
    assert_empty WebsitePublication.published
    record = WebsitePublication.create_draft!(organization: @organization, actor: @publisher, calendar_event: source)
    assert_raises(WebsitePublication::Conflict) { record.approve_eligibility!(actor: @publisher, version: record.lock_version, source_version: nil, reason: "Unreviewed") }
    assert_raises(ArgumentError) { record.publish!(actor: @publisher, version: record.lock_version, source_version: source.lock_version) }
    source.update!(calendar_category: "honor_guard")
    assert_equal "internal", source.website_designation
  end
end
