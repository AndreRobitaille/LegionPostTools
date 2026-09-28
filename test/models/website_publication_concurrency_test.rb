require "test_helper"
require "timeout"
require_relative "../support/website_publishing_support"

class WebsitePublicationConcurrencyTest < ActiveSupport::TestCase
  include WebsitePublishingSupport
  self.use_transactional_tests = false
  setup { setup_publisher }
  teardown do
    if @organization
      ids = WebsitePublication.where(organization: @organization).pluck(:id)
      WebsitePublicationEvent.where(website_publication_id: ids).delete_all
      WebsitePortrait.where(website_publication_id: ids).delete_all
      WebsitePublication.where(id: ids).delete_all
      CalendarEvent.where(organization_id: @organization.id).delete_all
      WebsiteCalendarChange.where(organization_id: @organization.id).delete_all
      @organization.reload.destroy!
      @publisher.person.destroy!
    end
    teardown_publisher
  end

  test "automatic calendar activation serializes with listing restrictions in both commit orders" do
    [ true, false ].each do |activate_first|
      source = event_source(calendar_category: "public_event")
      policy = WebsitePublishing::CalendarPolicy.new(@organization)
      token = policy.preview(types: %w[public_event])[:review_token]
      activate = -> { WebsitePublishing::CalendarPolicy.new(Organization.find(@organization.id)).apply!(actor: User.find(@publisher.id), review_token: token) }
      hide = -> { CalendarEvent.find(source.id).update!(website_listing: "hide") }
      results = in_commit_order(*(activate_first ? [ activate, hide ] : [ hide, activate ]))
      assert_nil results.first
      if activate_first
        assert_nil results.last
      else
        assert_kind_of WebsitePublishing::CalendarPolicy::Conflict, results.last
      end
      feed = WebsitePublishing::Feed.new(@organization.reload, origin: "https://publisher.example.test")
      assert_raises(ActiveRecord::RecordNotFound) { feed.event_detail(source.website_public_id) }
    end
  end

  test "both real commit orders serialize publication against every source restriction and edit" do
    %i[edit cancel private internal category delete].each do |action|
      [ true, false ].each do |publish_first|
        record = event_publication
        source_id = record.calendar_event_id
        publication_version = record.lock_version
        source_version = record.calendar_event.lock_version
        publish = -> { WebsitePublication.find(record.id).publish!(actor: User.find(@publisher.id), version: publication_version, source_version: source_version) }
        restriction = lambda do
          source = CalendarEvent.find(source_id)
          case action
          when :edit then source.update!(location: "Pending change")
          when :cancel then source.update!(cancelled: true)
          when :private then source.update!(visibility: "members"); source.update!(visibility: "public")
          when :internal then source.update!(website_designation: "internal")
          when :category then source.update!(calendar_category: "honor_guard"); source.update!(calendar_category: "other")
          when :delete then source.destroy!
          end
        end
        results = in_commit_order(*(publish_first ? [ publish, restriction ] : [ restriction, publish ]))
        assert_nil results.first
        if publish_first
          assert_nil results.last
        else
          assert_kind_of WebsitePublication::Conflict, results.last
        end
        record.reload
        case action
        when :edit then assert_nil record.snapshot["location"]
        when :cancel then assert record.snapshot["cancelled"]
        else assert_equal "withdrawn", record.status
        end
      end
    end
  end

  test "both commit orders serialize publication against withdrawal consent revocation and draft edits" do
    %i[withdraw revoke draft].each do |action|
      [ true, false ].each do |publish_first|
        record = story
        version = record.lock_version
        publish = -> { WebsitePublication.find(record.id).publish!(actor: User.find(@publisher.id), version: version) }
        restriction = lambda do
          current = WebsitePublication.find(record.id)
          actor = User.find(@publisher.id)
          if action == :draft
            current.edit_draft!(actor: actor, version: current.lock_version, attributes: { introduction: "New draft" })
          else
            current.withdraw!(actor: actor, version: current.lock_version, revoke_consent: action == :revoke)
          end
        end
        results = in_commit_order(*(publish_first ? [ publish, restriction ] : [ restriction, publish ]))
        assert_nil results.first
        (publish_first && action != :draft) ? assert_nil(results.last) : assert_kind_of(WebsitePublication::Conflict, results.last)
        record.reload
        action == :draft ? assert_equal("A synthetic introduction.", record.snapshot["introduction"]) : assert_equal("withdrawn", record.status)
      end
    end
  end

  test "HTML and bearer API source restrictions race safely with publish in either commit order" do
    @publisher.permission_grants.create!(capability: "manage_settings")
    _token, secret = AgentAccessToken.issue!(user: @publisher, name: "Synthetic concurrency", expires_in: 1.day)
    session_record = Session.create!(user: @publisher, ip_address: "127.0.0.1", user_agent: "test", last_seen_at: Time.current, authenticated_at: Time.current)
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session_record.id
    %i[html api].each do |transport|
      %i[cancel private internal category delete].each do |action|
        [ true, false ].each do |publish_first|
          record = event_publication
          source = record.calendar_event
          version = record.lock_version
          source_version = source.lock_version
          publish = -> { WebsitePublication.find(record.id).publish!(actor: User.find(@publisher.id), version: version, source_version: source_version) }
          restriction = lambda do
            client = ActionDispatch::Integration::Session.new(Rails.application)
            changes = case action
            when :cancel then { cancelled: true }
            when :private then { visibility: "members" }
            when :internal then { website_designation: "internal" }
            when :category then { calendar_category: "planning_meeting" }
            else {}
            end
            if transport == :api
              headers = { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => SecureRandom.uuid }
              client.public_send(action == :delete ? :delete : :patch, "/api/calendar_events/#{source.id}", params: { lock_version: source_version, **changes }, headers: headers, as: :json)
              raise "API restriction failed: #{client.response.status}" unless [ 200, 204 ].include?(client.response.status)
            else
              client.cookies[:session_id] = jar["session_id"]
              if action == :delete
                client.delete("/calendar_events/#{source.id}", params: { lock_version: source_version })
              else
                client.patch("/calendar_events/#{source.id}", params: { calendar_event: { lock_version: source_version, starts_at_date: "03 OCT 2026", starts_at_time: "18:00", **changes } })
              end
              raise "HTML restriction failed: #{client.response.status}" unless [ 302, 303 ].include?(client.response.status)
            end
          end
          results = in_commit_order(*(publish_first ? [ publish, restriction ] : [ restriction, publish ]))
          assert_nil results.first
          publish_first ? assert_nil(results.last) : assert_kind_of(WebsitePublication::Conflict, results.last)
          record.reload
          action == :cancel ? assert(record.snapshot["cancelled"]) : assert_equal("withdrawn", record.status)
        end
      end
    end
  end

  private

  # Separate committed connections; prove the contender is waiting in PostgreSQL,
  # then release the first transaction. No timing-only assumption about ordering.
  def in_commit_order(first, second)
    locked = Queue.new
    release = Queue.new
    contender = Queue.new
    thread_one = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        WebsitePublishing::Boundary.synchronize(@organization.id) do
          first.call
          locked << true
          release.pop
        end
      end
      nil
    rescue StandardError => error
      locked << error
      error
    end
    readiness = Timeout.timeout(10) { locked.pop }
    raise readiness if readiness.is_a?(Exception)
    thread_two = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        contender << connection.select_value("SELECT pg_backend_pid()")
        second.call
      end
      nil
    rescue StandardError => error
      error
    end
    pid = Timeout.timeout(10) { contender.pop }
    Timeout.timeout(10) do
      loop do
        waiting = ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value("SELECT EXISTS(SELECT 1 FROM pg_locks WHERE pid = #{Integer(pid)} AND NOT granted)") }
        break if waiting
        sleep 0.01
      end
    end
    release << true
    [ thread_one.value, thread_two.value ]
  ensure
    release << true if release
    [ thread_one, thread_two ].compact.each { |thread| thread.join(10) || thread.kill }
  end
end
