require "test_helper"

class OfficerTurnoverAuthorityTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 10, 12)
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    AmericanLegionPostPreset.apply_to(@organization)
    @body = @organization.meeting_bodies.find_by!(slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 2.weeks.ago, title: "Recorded meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @starts_on = Date.current + 1
    @ends_on = Date.current + 2
  end

  teardown { travel_back }

  %w[Commander Adjutant].each do |office|
    test "#{office} current duties follow future inclusive expired inactive and renamed assignments through HTML and the same bearer" do
      actor, assignment, headers = assigned_user(office, starts_on: @starts_on, ends_on: @ends_on)
      sign_in_as(actor)
      assert_drafting(headers, allowed: false, title: "Future forbidden heading")
      travel_to Time.zone.local(2026, 11, 11, 12)
      assert_drafting(headers, allowed: true, title: "Start-day reviewed heading")
      assignment.position_title.update!(name: "Renamed #{office} office")
      travel_to Time.zone.local(2026, 11, 12, 12)
      assert_drafting(headers, allowed: true, title: "Inclusive-end reviewed heading")
      assert_identity_duty(actor, headers, office)
      travel_to Time.zone.local(2026, 11, 13, 12)
      assert_drafting(headers, allowed: false, title: "Expired forbidden heading")
      assert_empty actor.reload.permission_grants
      get "/api/meetings/#{@meeting.id}", headers:, as: :json
      assert_response :success
      assert_equal @meeting.id, response.parsed_body.dig("meeting", "id")
      assert_nil response.parsed_body.dig("meeting", "minutes")

      assignment.update!(ends_on: nil)
      assignment.position_title.update!(active: false)
      assert_drafting(headers, allowed: false, title: "Inactive forbidden heading")
      assignment.position_title.update!(active: true)
      actor.permission_grants.create!(capability: "manage_minutes")
      assignment.update!(ends_on: Date.current - 1)
      assert_drafting(headers, allowed: true, title: "Manual drafting exception", membership: false)
      assert_equal [ "manage_minutes" ], actor.reload.permission_grants.pluck(:capability)
      assert_not actor.private_agenda_notes_access?
      assert_not actor.can_manage_calendar?
      assert_not actor.full_membership_access?
      %w[approve_minutes attest_minutes record_minutes_approval manage_settings publish_public_content].each { |duty| assert_not actor.can?(duty) }
    end
  end

  test "1st Vice membership and honorary office never imply meeting official technical or publication duties" do
    actor, _assignment, headers = assigned_user("1st Vice Commander", starts_on: Date.current)
    sign_in_as(actor)
    get "/api/membership/summary?membership_year=2026", headers:, as: :json
    assert_response :success
    assert_drafting(headers, allowed: false, title: "Vice forbidden heading", membership: true)
    %w[approval attestation].each do |action|
      before = official_graph
      post "/api/meetings/#{@meeting.id}/minutes/#{action}", headers: headers.merge("Idempotency-Key" => SecureRandom.uuid), as: :json
      assert_response :forbidden, "#{request.method} #{request.path}: #{response.body}"
      assert_equal before, official_graph
    end
    get new_admin_meeting_minutes_membership_approval_path(@meeting)
    assert_redirected_to root_path
    get admin_website_publications_path
    assert_redirected_to root_path
    get admin_administrators_path
    assert_redirected_to root_path
    assert_not actor.private_agenda_notes_access?
    assert_not actor.can_manage_calendar?
    honorary = @organization.position_titles.create!(name: "Past Post Commander", display_order: 20)
    honorary.position_assignments.create!(person: actor.person, starts_on: Date.current)
    travel_to Time.zone.local(2026, 11, 11, 12)
    actor.person.position_assignments.where.not(position_title: honorary).each { |assignment| assignment.update!(ends_on: Date.current - 1) }
    get "/api/membership/summary?membership_year=2026", headers:, as: :json
    assert_response :forbidden, "#{request.method} #{request.path}: #{response.body}"
    assert_drafting(headers, allowed: false, title: "Honorary forbidden heading")
    assert_empty actor.permission_grants
  end

  test "an exact cached bearer retry cannot return privileged minutes after position authority expires" do
    actor, assignment, headers = assigned_user("Commander", starts_on: Date.current, ends_on: Date.current)
    headers = headers.merge("Idempotency-Key" => "turnover-heading-retry")
    attributes = { title: "Private officer working heading", lock_version: @minutes.lock_version }
    patch "/api/meetings/#{@meeting.id}/minutes", params: attributes, headers:, as: :json
    assert_response :success
    original = @minutes.reload.attributes
    travel_to Time.zone.local(2026, 11, 11, 12)
    assert_equal Date.new(2026, 11, 10), assignment.reload.ends_on
    assert_not actor.reload.can?("manage_minutes")
    patch "/api/meetings/#{@meeting.id}/minutes", params: attributes, headers:, as: :json
    assert_equal original, @minutes.reload.attributes
    assert_not_includes response.body, "Private officer working heading"
    assert_response :forbidden, "#{request.method} #{request.path}: #{response.body}"
  end

  test "a still permitted Meeting retry omits restricted summaries when only manual agenda authority survives" do
    actor, assignment, headers = assigned_user("Commander", starts_on: Date.current, ends_on: Date.current)
    actor.permission_grants.create!(capability: "manage_agendas")
    @minutes.update!(title: "Private cached working heading")
    transcript = MeetingTranscripts::Create.new(meeting: @meeting, created_by: actor, retention_policy: "retain_restricted", pasted_text: "Restricted synthetic source").call
    token = actor.agent_access_tokens.sole
    headers = headers.merge("Idempotency-Key" => "meeting-partial-authority-retry")
    input = { title: "Deliberately updated occurrence", lock_version: @meeting.lock_version }
    patch "/api/meetings/#{@meeting.id}", params: input, headers:, as: :json
    assert_response :success
    receipt = response.body
    assert_equal transcript.id, response.parsed_body.dig("meeting", "transcript", "id")
    assert_equal "Private cached working heading", response.parsed_body.dig("meeting", "minutes", "title")
    execution = token.agent_api_executions.find_by!(idempotency_key: "meeting-partial-authority-retry")
    original_execution = execution.attributes
    original_records = [ @meeting.reload.attributes, @minutes.reload.attributes, transcript.reload.attributes ]
    travel_to Time.zone.local(2026, 11, 11, 12)
    patch "/api/meetings/#{@meeting.id}", params: input, headers:, as: :json
    assert_nil response.parsed_body.dig("meeting", "transcript")
    assert_nil response.parsed_body.dig("meeting", "minutes")
    assert_not_includes response.body, "Private cached working heading"
    assert_response :success
    assert_equal "Deliberately updated occurrence", response.parsed_body.dig("meeting", "title")
    assert_equal original_records, [ @meeting.reload.attributes, @minutes.reload.attributes, transcript.reload.attributes ]
    assert_equal original_execution, execution.reload.attributes
    exception = actor.permission_grants.create!(capability: "approve_minutes")
    patch "/api/meetings/#{@meeting.id}", params: input, headers:, as: :json
    assert_nil response.parsed_body.dig("meeting", "transcript")
    assert_equal "Private cached working heading", response.parsed_body.dig("meeting", "minutes", "title")
    assert_response :success
    assert_equal original_records, [ @meeting.reload.attributes, @minutes.reload.attributes, transcript.reload.attributes ]
    assert_equal original_execution, execution.reload.attributes
    exception.destroy!
    assignment.update!(ends_on: nil)
    patch "/api/meetings/#{@meeting.id}", params: input, headers:, as: :json
    assert_response :success
    assert_equal receipt, response.body
    assert_equal original_records, [ @meeting.reload.attributes, @minutes.reload.attributes, transcript.reload.attributes ]
    assert_equal original_execution, execution.reload.attributes
  end

  test "a deleted agenda receipt remains available with current agenda authority and hides expired minutes authority" do
    actor, _assignment, headers = assigned_user("Commander", starts_on: Date.current, ends_on: Date.current)
    actor.permission_grants.create!(capability: "manage_agendas")
    template = @organization.meeting_types.create!(name: "Retry template", slug: "retry-template", position: 1)
    @meeting.update!(meeting_type: template)
    agenda = DatedAgenda.create_from_template!(meeting: @meeting)
    @minutes.update!(meeting_type: template, title: "Private deleted-agenda receipt heading")
    headers = headers.merge("Idempotency-Key" => "delete-unused-agenda-retry")
    path = "/api/dated_agendas/#{agenda.id}"
    delete path, headers:, as: :json
    assert_response :success
    assert_equal "Private deleted-agenda receipt heading", response.parsed_body.dig("meeting", "minutes", "title")
    assert_not DatedAgenda.exists?(agenda.id)
    original_records = [ @meeting.reload.attributes, @minutes.reload.attributes ]
    execution = actor.agent_access_tokens.sole.agent_api_executions.find_by!(idempotency_key: "delete-unused-agenda-retry")
    original_execution = execution.attributes
    travel_to Time.zone.local(2026, 11, 11, 12)
    delete path, headers:, as: :json
    assert_nil response.parsed_body.dig("meeting", "minutes")
    assert_not_includes response.body, "Private deleted-agenda receipt heading"
    assert_response :success
    assert_equal agenda.id, response.parsed_body.dig("deleted_dated_agenda", "id")
    assert_not DatedAgenda.exists?(agenda.id)
    assert_equal original_records, [ @meeting.reload.attributes, @minutes.reload.attributes ]
    assert_equal original_execution, execution.reload.attributes
  end

  %w[Commander Adjutant].each do |office|
    test "#{office} records actual later Meeting approval with a human confirmation and no manual grant" do
      actor, _assignment, headers = assigned_user(office, starts_on: Date.current)
      attester_headers = office == "Adjutant" ? headers : assigned_user("Adjutant", starts_on: Date.current).last
      post "/api/meetings/#{@meeting.id}/minutes/attestation", headers: attester_headers.merge("Idempotency-Key" => SecureRandom.uuid), as: :json
      assert_response :success
      revision = @minutes.reload.member_revision
      original_revision = revision.attributes
      later = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago, title: "Later recorded meeting")
      browser_session = sign_in_as(actor)
      get new_admin_meeting_minutes_membership_approval_path(@meeting)
      assert_response :success
      post admin_meeting_minutes_membership_approval_path(@meeting), params: {
        minutes_membership_approval: { approving_meeting_id: later.id, disposition: "approved_as_presented" }
      }
      assert_redirected_to new_official_action_reauthentication_path
      confirmation = actor.official_action_confirmations.order(:id).last
      assert_equal "record_membership_approval", confirmation.action
      assert_equal browser_session.id, confirmation.session_id
      assert_nil confirmation.agent_access_token_id
      perform_enqueued_jobs { post official_action_reauthentication_path }
      code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]
      assert code.present?
      post verify_official_action_reauthentication_path, params: { code: }
      assert_redirected_to admin_meeting_minutes_path(@meeting)
      assert_predicate @minutes.reload, :membership_approved?
      approval = @minutes.membership_approval
      assert_equal actor.id, approval.recorded_by_id
      assert_equal later.id, approval.approving_meeting_id
      assert_equal revision.id, approval.minutes_revision_id
      assert_equal actor.person.full_name, approval.recorder_name
      assert confirmation.reload.confirmed_at
      assert confirmation.consumed_at
      assert_equal original_revision, revision.reload.attributes
      assert_empty actor.reload.permission_grants
    end
  end

  private

  def assigned_user(office, starts_on:, ends_on: nil)
    actor = User.create!(person: Person.create!(first_name: "Synthetic", last_name: office), email_address: "turnover-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    assignment = @organization.position_titles.find_by!(name: office).position_assignments.create!(person: actor.person, starts_on:, ends_on:)
    _token, plaintext = AgentAccessToken.issue!(user: actor, name: "Same officer delegate", expires_in: 1.year)
    [ actor, assignment, { "Authorization" => "Bearer #{plaintext}" } ]
  end

  def assert_drafting(headers, allowed:, title:, membership: allowed)
    original = @minutes.reload.attributes
    patch "/api/meetings/#{@meeting.id}/minutes", params: { title:, lock_version: @minutes.lock_version }, headers: headers.merge("Idempotency-Key" => SecureRandom.uuid), as: :json
    if allowed
      assert_response :success
      assert_equal title, @minutes.reload.title
    else
      assert_equal original, @minutes.reload.attributes
      assert_response :forbidden, "#{request.method} #{request.path}: #{response.body}"
    end
    get edit_admin_meeting_minutes_path(@meeting)
    if allowed
      assert_response :success
      assert_select "input[name='meeting_minutes[title]']", count: 1
    else
      assert_redirected_to root_path
    end
    patch admin_meeting_minutes_path(@meeting), params: { meeting_minutes: { title: "HTML #{title}", lock_version: @minutes.lock_version } }
    if allowed
      assert_redirected_to admin_meeting_minutes_path(@meeting)
      assert_equal "HTML #{title}", @minutes.reload.title
    else
      assert_equal original, @minutes.reload.attributes
      assert_redirected_to root_path
    end
    get "/api/membership/summary?membership_year=2026", headers:, as: :json
    assert_response(membership ? :success : :forbidden)
  end

  def assert_identity_duty(actor, headers, office)
    permitted = office == "Commander" ? "approval" : "attestation"
    denied = office == "Commander" ? "attestation" : "approval"
    before = official_graph
    post "/api/meetings/#{@meeting.id}/minutes/#{denied}", headers: headers.merge("Idempotency-Key" => SecureRandom.uuid), as: :json
    assert_response :forbidden, "#{request.method} #{request.path}: #{response.body}"
    assert_equal before, official_graph
    post "/api/meetings/#{@meeting.id}/minutes/#{permitted}", headers: headers.merge("Idempotency-Key" => SecureRandom.uuid), as: :json
    assert_response :success
    assert_equal actor.id, @minutes.reload.lifecycle_events.last.actor_id
    assert_equal actor.person.full_name, permitted == "approval" ? @minutes.current_revision.approver_name : @minutes.current_revision.attestation.attester_name
    if permitted == "approval"
      assert_predicate @minutes, :approved?
    else
      assert_predicate @minutes, :attested?
      get new_admin_meeting_minutes_membership_approval_path(@meeting)
      assert_response :success
      @minutes.reopen_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(minutes: @minutes, user: actor, action: "reopen", action_payload: { reason: "Synthetic continued editing." }, evidence_note: "Synthetic authority test."))
    end
  end

  def official_graph
    [ @minutes.reload.attributes, @minutes.revisions.map(&:attributes), @minutes.lifecycle_events.map(&:attributes), MinutesAttestation.where(minutes_revision: @minutes.revisions).map(&:attributes) ]
  end
end
