require "test_helper"

class ApiGuidanceAuthorityTest < ActionDispatch::IntegrationTest
  PROFILES = [
    { name: "Member", grants: [], workspace: false, transcript: false, draft: false, handoff: false, attest: false, publish: false },
    { name: "Drafter", grants: %w[manage_minutes], workspace: true, transcript: true, draft: true, handoff: false, attest: false, publish: false },
    { name: "Handoff", grants: %w[approve_minutes], workspace: true, transcript: false, draft: false, handoff: true, attest: false, publish: false },
    { name: "Attester", grants: %w[attest_minutes], workspace: true, transcript: false, draft: false, handoff: false, attest: true, publish: false },
    { name: "Internal viewer", grants: %w[view_internal_records], workspace: true, transcript: true, draft: false, handoff: false, attest: false, publish: false },
    { name: "Administrator", grants: %w[manage_settings], workspace: true, transcript: true, draft: true, handoff: false, attest: false, publish: false },
    { name: "Publisher", grants: %w[publish_public_content], workspace: false, transcript: false, draft: false, handoff: false, attest: false, publish: true }
  ].freeze

  setup do
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: 1.day.ago, title: "Synthetic recorded meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @minutes.update!(title: "Private working heading")
  end

  PROFILES.each do |profile|
    test "#{profile[:name]} JSON and Markdown guidance agrees with actual permitted and denied actions" do
      actor = User.create!(person: Person.create!(first_name: "Synthetic", last_name: profile[:name]), email_address: "guidance-#{SecureRandom.hex(4)}@example.test", email_verified_at: Time.current)
      profile[:grants].each { |capability| actor.permission_grants.create!(capability:) }
      MeetingTranscripts::Create.new(meeting: @meeting, created_by: actor, retention_policy: "retain_restricted", pasted_text: "Restricted synthetic source evidence").call
      token, secret = AgentAccessToken.issue!(user: actor, name: "Contract delegate", expires_in: 1.day)
      @headers = { "Authorization" => "Bearer #{secret}" }
      get "/api", headers: @headers, as: :json
      assert_response :success
      @handbook = response.parsed_body
      assert_equal actor.person.full_name, @handbook.dig("caller", "name")
      assert_nil @handbook["csrf_token"]
      get "/api", headers: @headers.merge("Accept" => "text/markdown")
      assert_response :success
      @markdown = response.body
      assert_match(%r{\Atext/markdown}, response.media_type)
      assert_advertised("GET", "/api/meetings", true)
      assert_advertised("GET", "/api/meetings/:meeting_id/minutes", profile[:workspace])
      assert_advertised("GET", "/api/meetings/:meeting_id/transcript", profile[:transcript])
      assert_advertised("PATCH", "/api/meetings/:meeting_id/minutes", profile[:draft])
      assert_advertised("POST", "/api/meetings/:meeting_id/minutes/approval", profile[:handoff], group: "only_when_asked")
      assert_advertised("POST", "/api/meetings/:meeting_id/minutes/attestation", profile[:attest], group: "only_when_asked")
      assert_advertised("GET", "/api/website_publications", profile[:publish])
      assert @handbook.fetch("rules").any? { |rule| rule.include?("Reopening and membership approval currently require the signed-in website") }
      assert_includes @markdown, "later amendments are not implemented"
      assert @handbook.fetch("rules").any? { |rule| rule.include?("Token creation and management are not API operations") }
      assert_not (@handbook.fetch("common_actions") + @handbook.fetch("only_when_asked")).any? { |action| action.fetch("path").match?(/access_tokens|minutes\/reopen|minutes\/membership_approval/) }

      get "/api/meetings", headers: @headers, as: :json
      assert_response :success
      assert_equal [ @meeting.id ], response.parsed_body.fetch("meetings").map { |meeting| meeting.fetch("id") }
      get minutes_path, headers: @headers, as: :json
      assert_response(profile[:workspace] ? :success : :forbidden)
      if profile[:workspace]
        assert_equal "Private working heading", response.parsed_body.dig("minutes", "title")
      else
        assert_not_includes response.body, "Private working heading"
      end
      get "/api/meetings/#{@meeting.id}/transcript?include_content=true", headers: @headers, as: :json
      assert_response(profile[:transcript] ? :success : :forbidden)
      if profile[:transcript]
        assert_equal "Restricted synthetic source evidence", response.parsed_body.dig("transcript", "content")
      else
        assert_not_includes response.body, "Restricted synthetic source evidence"
      end
      original = @minutes.reload.attributes
      patch minutes_path, params: { title: "Explicit reviewed heading", lock_version: @minutes.lock_version }, headers: write_headers, as: :json
      if profile[:draft]
        assert_response :success
        assert_equal "Explicit reviewed heading", @minutes.reload.title
      else
        assert_equal original, @minutes.reload.attributes
        assert_response :forbidden
      end
      get "/api/website_publications", headers: @headers, as: :json
      assert_response(profile[:publish] ? :success : :forbidden)
      assert_equal [], response.parsed_body.fetch("website_publications") if profile[:publish]

      sign_in_as(actor)
      { "approval" => profile[:handoff], "attestation" => profile[:attest] }.each do |action, permitted|
        original_graph = official_graph
        post "#{minutes_path}/#{action}", as: :json
        assert_equal original_graph, official_graph
        assert_response(permitted ? :unprocessable_entity : :forbidden)
        assert_match(/signed-in minutes screen.*human browser/, response.parsed_body.fetch("error")) if permitted
        post "#{minutes_path}/#{action}", headers: write_headers, as: :json
        if permitted
          assert_response :success
          confirmation = actor.official_action_confirmations.order(:id).last
          assert_equal token.id, confirmation.agent_access_token_id
          assert_equal "delegated_agent", confirmation.confirmation_method
          assert confirmation.confirmed_at
          assert confirmation.consumed_at
          assert_equal actor.id, @minutes.reload.lifecycle_events.last.actor_id
        else
          assert_equal original_graph, official_graph
          assert_response :forbidden
          assert_not_includes response.body, "Private working heading"
        end
      end
      assert_equal profile[:grants].sort, actor.reload.permission_grants.pluck(:capability).sort
    end
  end

  private

  def assert_advertised(method, path, permitted, group: "common_actions")
    advertised = @handbook.fetch(group).any? { |action| action.fetch("method") == method && action.fetch("path") == path }
    assert_equal permitted, advertised, "#{method} #{path} must match independent expected duties"
    if permitted
      assert_includes @markdown, "#{method} #{path}"
    else
      assert_not_includes @markdown, "#{method} #{path}"
    end
  end

  def minutes_path
    "/api/meetings/#{@meeting.id}/minutes"
  end

  def write_headers
    @headers.merge("Idempotency-Key" => SecureRandom.uuid)
  end

  def official_graph
    [ @minutes.reload.attributes, @minutes.revisions.map(&:attributes), @minutes.lifecycle_events.map(&:attributes), OfficialActionConfirmation.where(meeting_minutes: @minutes).map(&:attributes), MinutesAttestation.where(minutes_revision: @minutes.revisions).map(&:attributes) ]
  end
end
