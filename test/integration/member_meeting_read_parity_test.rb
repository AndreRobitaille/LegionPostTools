require "test_helper"

class MemberMeetingReadParityTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 2.weeks.ago, title: "Recorded meeting")
    @member = user("Member")
    @commander = user("Commander", "manage_agendas", "manage_minutes", "approve_minutes")
    @adjutant = user("Adjutant", "manage_minutes", "attest_minutes", "record_minutes_approval")
    @token, plaintext = AgentAccessToken.issue!(user: @member, name: "Member reader", expires_in: 1.day)
    @bearer = { "Authorization" => "Bearer #{plaintext}" }
    sign_in_as(@member)
  end

  test "session and delegate read the exact member revision across handoff and corrections without working evidence" do
    agenda = DatedAgenda.create_from_template!(meeting: @meeting)
    agenda.dated_agenda_items.create!(title: "Report", behavior_type: "report_slot", position: 1,
      body: "Member agenda wording", show_wording_in_minutes: true, commander_notes: "Private Commander cue")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    item = @minutes.items.find_by!(title: "Report")
    item.update!(body: "First reviewed narrative")
    assert_unavailable_minutes
    handoff!
    assert_unavailable_minutes
    attest!
    first = @minutes.member_revision
    assert_member_minutes(first, title: "Recorded meeting", wording: "First reviewed narrative", label: "Awaiting meeting approval", authority: "attested")

    @minutes.reopen_with_confirmation!(confirmation: confirm(@commander, "reopen", reason: "Correct the report."))
    @minutes.update!(title: "Corrected heading")
    item.update!(body: "Second reviewed narrative")
    assert_member_minutes(first, title: "Recorded meeting", wording: "First reviewed narrative", label: "Correction in progress — last attested copy", authority: "attested", excluded: [ "Corrected heading", "Second reviewed narrative" ])
    handoff!
    assert_member_minutes(first, title: "Recorded meeting", wording: "First reviewed narrative", label: "Correction in progress — last attested copy", authority: "attested", excluded: [ "Corrected heading", "Second reviewed narrative" ])
    attest!
    second = @minutes.member_revision
    later = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.ago, title: "Later approval meeting")
    @minutes.record_membership_approval_with_confirmation!(confirmation: confirm(@adjutant, "record_membership_approval",
      approving_meeting_id: later.id, disposition: "approved_as_corrected", corrections_pending: true, factual_note: "Correct the report count."))
    item.update!(body: "Final corrected narrative")
    assert_member_minutes(second, title: "Corrected heading", wording: "Second reviewed narrative",
      label: "Approved with corrections — final copy being prepared", authority: "attested", excluded: [ "Final corrected narrative" ])
    attest!
    final = @minutes.member_revision
    assert_member_minutes(final, title: "Corrected heading", wording: "Final corrected narrative", label: "Approved as corrected", authority: "official")
    assert_equal later.id, @minutes.membership_approval.approving_meeting_id
    assert_equal first.sha256, first.reload.sha256
    assert_equal second.sha256, second.reload.sha256
  end

  test "published member agenda projection excludes hidden wording inactive rows cues and officer roll call" do
    agenda = DatedAgenda.create_from_template!(meeting: @meeting)
    agenda.dated_agenda_items.create!(title: "Visible wording", behavior_type: "business_item", position: 1, body: "Public member wording", show_wording_on_agenda: true, commander_notes: "Private Commander cue")
    agenda.dated_agenda_items.create!(title: "Hidden wording", behavior_type: "business_item", position: 2, body: "Hidden draft wording", show_wording_on_agenda: false)
    agenda.dated_agenda_items.create!(title: "Summary fallback", behavior_type: "report_slot", position: 3, summary: "Member screen fallback")
    agenda.dated_agenda_items.create!(title: "Inactive heading", behavior_type: "report_slot", position: 4, active: false, body: "Inactive private text")
    roll_call = agenda.dated_agenda_items.create!(title: "Roll call", behavior_type: "roll_call", position: 5)
    roll_call.roll_call_entries.create!(office_name: "Commander", person_name: "Private roll call officer", position: 1)
    [ {}, @bearer ].each do |headers|
      get member_path("agenda"), headers:, as: :json
      assert_response :not_found
      get "/api/meetings/#{@meeting.id}", headers:, as: :json
      assert_response :success
      assert_nil response.parsed_body.dig("meeting", "agenda")
      assert_nil response.parsed_body.dig("meeting", "member_documents", "agenda")
    end
    agenda.approve!(@commander)
    get member_path("agenda"), headers: @bearer, as: :json
    assert_response :not_found
    get "/api/meetings/#{@meeting.id}", headers: @bearer, as: :json
    assert_nil response.parsed_body.dig("meeting", "agenda")
    assert_nil response.parsed_body.dig("meeting", "member_documents", "agenda")
    agenda.publish!(@commander)
    original = agenda.reload.attributes

    [ {}, @bearer ].each do |headers|
      get member_path("agenda"), headers:, as: :json
      assert_response :success
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      payload = response.parsed_body.fetch("agenda")
      items = payload.fetch("sections").flat_map { |section| section.fetch("items") }.index_by { |entry| entry.fetch("title") }
      assert_equal "Public member wording", items.fetch("Visible wording").fetch("wording")
      assert_nil items.fetch("Hidden wording").fetch("wording")
      assert_equal "Member screen fallback", items.fetch("Summary fallback").fetch("summary")
      assert_not items.key?("Inactive heading")
      %w[Hidden\ draft\ wording Private\ Commander\ cue Private\ roll\ call\ officer Inactive\ private\ text].each { |private_text| assert_not_includes response.body, private_text }
      assert_equal original, agenda.reload.attributes
      get "/api/meetings/#{@meeting.id}", headers:, as: :json
      assert_equal agenda.id, response.parsed_body.dig("meeting", "member_documents", "agenda", "id")
    end
  end

  test "same token loses working access after officer duties end but retains member document reading" do
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @minutes.sections.first.items.create!(title: "Report", behavior_type: "report_slot", position: 1, body: "Reviewed record")
    attest!
    grant = @member.permission_grants.create!(capability: "manage_minutes")
    get "/api/meetings/#{@meeting.id}/minutes", headers: @bearer, as: :json
    assert_response :success
    assert_equal @minutes.id, response.parsed_body.dig("minutes", "id")
    grant.destroy!
    get "/api/meetings/#{@meeting.id}/minutes", headers: @bearer, as: :json
    assert_response :forbidden
    assert_not_includes response.body, "Reviewed record"
    assert_member_minutes(@minutes.member_revision, title: "Recorded meeting", wording: "Reviewed record", label: "Awaiting meeting approval", authority: "attested")
    patch "/api/meetings/#{@meeting.id}", headers: @bearer.merge("Idempotency-Key" => SecureRandom.uuid), params: { title: "Unauthorized rewrite" }, as: :json
    assert_response :forbidden
    assert_equal "Recorded meeting", @meeting.reload.title
  end

  test "anonymous disabled revoked and foreign reads fail without record content" do
    foreign = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign_body = foreign.meeting_bodies.create!(name: "Membership", slug: "membership")
    foreign_meeting = create_meeting!(organization: foreign, meeting_body: foreign_body, starts_at: 1.day.ago, title: "Foreign private meeting")
    [ "/api/meetings/#{foreign_meeting.id}", "/api/meetings/#{foreign_meeting.id}/member_documents/minutes" ].each do |path|
      get path, headers: @bearer, as: :json
      assert_response :not_found
      assert_not_includes response.body, "Foreign private meeting"
    end
    @member.update!(disabled_at: Time.current, disabled_reason: "manual")
    [ {}, @bearer ].each do |headers|
      get "/api/meetings", headers:, as: :json
      assert_response :unauthorized
      assert_not_includes response.body, "Recorded meeting"
    end
    @member.update!(disabled_at: nil, disabled_reason: nil)
    @token.update!(revoked_at: Time.current)
    get "/api/meetings", headers: @bearer, as: :json
    assert_response :unauthorized
    reset!
    get member_path("agenda"), as: :json
    assert_response :unauthorized
  end

  test "member PDF API selects only the attested revision during working corrections and reports renderer failure" do
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @minutes.sections.first.items.create!(title: "Report", behavior_type: "report_slot", position: 1, body: "Reviewed record")
    attest!
    revision = @minutes.member_revision
    @minutes.reopen_with_confirmation!(confirmation: confirm(@commander, "reopen", reason: "Correct the heading."))
    @minutes.update!(title: "Private working heading")
    original = [ @minutes.reload.attributes, revision.reload.attributes ]
    [ {}, @bearer ].each do |headers|
      rendered = nil
      renderer = ->(minutes:, revision:) { rendered = [ minutes.id, revision.id ]; "%PDF-1.7\nsynthetic selection probe" }
      with_stubbed_class_method(MeetingMinutesPdf, :render, renderer) { get "#{member_path('minutes')}/print", headers: }
      assert_response :success
      assert_equal [ @minutes.id, revision.id ], rendered
      assert_equal "application/pdf", response.media_type
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_match(/attested-minutes/, response.headers.fetch("Content-Disposition"))
      assert_equal original, [ @minutes.reload.attributes, revision.reload.attributes ]
    end
    renderer = ->(**) { raise MeetingMinutesPdf::GenerationError, "Synthetic unavailable renderer" }
    with_stubbed_class_method(MeetingMinutesPdf, :render, renderer) { get "#{member_path('minutes')}/print", headers: @bearer }
    assert_response :service_unavailable
    assert_equal "The document PDF could not be created. Try again.", response.parsed_body.fetch("error")
    assert_equal original, [ @minutes.reload.attributes, revision.reload.attributes ]
  end

  private

  def user(label, *capabilities)
    record = User.create!(person: Person.create!(first_name: "Synthetic", last_name: label), email_address: "parity-#{label.downcase}@example.com")
    capabilities.each { |capability| record.permission_grants.create!(capability:) }
    record
  end

  def member_path(document)
    "/api/meetings/#{@meeting.id}/member_documents/#{document}"
  end

  def confirm(actor, action, payload = {})
    OfficialActionConfirmation.record_external!(minutes: @minutes, user: actor, action:, action_payload: payload, evidence_note: "Synthetic read-parity lifecycle.")
  end

  def handoff!
    @minutes.reload.approve_with_confirmation!(confirmation: confirm(@commander, "approve"))
  end

  def attest!
    @minutes.reload.attest_with_confirmation!(confirmation: confirm(@adjutant, "attest"))
  end

  def assert_unavailable_minutes
    [ {}, @bearer ].each do |headers|
      get member_path("minutes"), headers:, as: :json
      assert_response :not_found
      get "/api/meetings/#{@meeting.id}", headers:, as: :json
      assert_response :success
      assert_nil response.parsed_body.dig("meeting", "member_documents", "minutes")
      assert_nil response.parsed_body.dig("meeting", "minutes")
    end
  end

  def assert_member_minutes(revision, title:, wording:, label:, authority:, excluded: [])
    original = [ @minutes.reload.attributes, revision.reload.attributes, revision.attestation.attributes, @minutes.membership_approval&.attributes ]
    [ {}, @bearer ].each do |headers|
      get member_path("minutes"), headers:, as: :json
      assert_response :success
      payload = response.parsed_body.fetch("minutes")
      assert_equal revision.id, payload.fetch("revision_id")
      assert_equal revision.sha256, payload.fetch("sha256")
      assert_equal authority, payload.fetch("authority")
      assert_equal label, payload.fetch("label")
      assert_equal title, payload.dig("document", "title")
      entries = payload.fetch("document").fetch("sections").flat_map { |section| section.fetch("items") }
      assert_includes entries.find { |item| item.fetch("title") == "Report" }.fetch("body_html"), wording
      %w[commander_notes transcript draft_runs source_dated_agenda_item_id lock_version official_action_confirmation].each { |private_key| assert_not_includes response.body, "\"#{private_key}\"" }
      assert_not_includes response.body, "Private Commander cue"
      excluded.each { |private_text| assert_not_includes response.body, private_text }
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      get "/api/meetings/#{@meeting.id}", headers:, as: :json
      summary = response.parsed_body.dig("meeting", "member_documents", "minutes")
      assert_equal revision.id, summary.fetch("revision_id")
      assert_equal label, summary.fetch("label")
      assert_nil response.parsed_body.dig("meeting", "minutes")
    end
    get meeting_minutes_path(@meeting)
    assert_response :success
    assert_select "h1", text: title
    assert_select ".member-minutes-status", text: /#{Regexp.escape(label)}/
    assert_select ".minutes-recorded-wording", text: /#{Regexp.escape(wording)}/
    excluded.each { |private_text| assert_not_includes response.body, private_text }
    assert_equal original, [ @minutes.reload.attributes, revision.reload.attributes, revision.attestation.reload.attributes, @minutes.membership_approval&.attributes ]
  end
end
