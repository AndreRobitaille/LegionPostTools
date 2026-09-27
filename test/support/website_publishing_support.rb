require "stringio"

module WebsitePublishingSupport
  def setup_publisher
    @organization = Organization.create!(name: "Synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @publisher = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Publisher"), email_address: "publisher-#{SecureRandom.hex(6)}@example.test")
    @publisher.permission_grants.create!(capability: "publish_public_content")
    @origin_before = ENV["PUBLIC_PUBLISHER_ORIGIN"]
    ENV["PUBLIC_PUBLISHER_ORIGIN"] = "https://publisher.example.test"
  end

  def teardown_publisher
    ENV["PUBLIC_PUBLISHER_ORIGIN"] = @origin_before
  end

  def image_upload(color = 100)
    StringIO.new(Vips::Image.black(640, 800).new_from_image([ color, 110, 140 ]).write_to_buffer(".png"))
  end

  def story(publish: true)
    record = WebsitePublication.create_draft!(organization: @organization, actor: @publisher)
    record.edit_draft!(actor: @publisher, version: record.lock_version, attributes: {
      display_name: "Avery (fictional)", introduction: "A synthetic introduction.",
      story: "No real member is represented.", conversation_starter: "Ask about this test.", portrait_alt: "Synthetic color field, not a person"
    }, portrait: image_upload)
    record.confirm_consent!(actor: @publisher, version: record.lock_version, note: "Synthetic test content only")
    record.publish!(actor: @publisher, version: record.lock_version) if publish
    record
  end

  def event_source(**attributes)
    @organization.calendar_events.create!({ title: "Synthetic public gathering", starts_at: Time.find_zone!("America/Chicago").local(2026, 10, 3, 18), visibility: "public", created_by: @publisher, updated_by: @publisher }.merge(attributes))
  end

  def event_publication(source = event_source)
    record = WebsitePublication.create_draft!(organization: @organization, actor: @publisher, calendar_event: source)
    record.approve_eligibility!(actor: @publisher, version: record.lock_version, source_version: source.lock_version, reason: "Synthetic public activity", resolve_flags: true)
    record.publish!(actor: @publisher, version: record.lock_version, source_version: source.reload.lock_version)
    record
  end

  def feature(*records)
    scope = WebsitePublication.where(organization: @organization, kind: "story").order(:id)
    WebsitePublication.feature!(organization: @organization, actor: @publisher, ids: records.map(&:public_id), versions: scope.pluck(:id, :lock_version).to_h.transform_keys(&:to_s).transform_values(&:to_s))
    records.each(&:reload)
  end
end
