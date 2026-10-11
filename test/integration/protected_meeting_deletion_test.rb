require "test_helper"

class ProtectedMeetingDeletionTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @officer = create_user("Officer", "manage_agendas", "manage_minutes", "attest_minutes", "record_minutes_approval")
    @member = create_user("Member")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 2.weeks.ago, title: "Recorded membership meeting")
    catalog = @organization.agenda_item_catalog_entries.create!(title: "Community report", category: "reports", behavior_type: "report_slot", position: 1, active: true)
    @type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: catalog, title: "Community report", position: 1, body: "Planned report wording.", show_wording_in_minutes: true, commander_notes: "Private officer cue.", active: true)
    @agenda = DatedAgenda.create_from_template!(meeting: @meeting)
    @item = @agenda.dated_agenda_items.find_by!(title: "Community report")
    roll_call = @agenda.dated_agenda_items.create!(title: "Officer roll call", position: 2, behavior_type: "roll_call")
    roll_call.roll_call_entries.create!(office_name: "Vacant Trustee", position: 1)
    @empty_section = @agenda.dated_agenda_sections.create!(title: "Other business", position: 2)
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    report = @minutes.items.find_by!(source_dated_agenda_item: @item)
    report.update!(body: "Members received the community report.")
    report.outcomes.create!(kind: "decision", text: "Continue the community program.", disposition: "adopted", position: 1)
    sign_in_as(@officer)
  end

  %w[draft attested membership_approved].each do |state|
    %w[type agenda item section api_agenda api_item].each do |target|
      test "#{target} deletion preserves the source graph and #{state} minutes" do
        advance_minutes_to(state)
        original = record_snapshot
        path = deletion_path(target)

        if target.start_with?("api_")
          _, secret = AgentAccessToken.issue!(user: @officer, name: "Synthetic delete", expires_in: 1.day)
          delete path, headers: { "Authorization" => "Bearer #{secret}", "Idempotency-Key" => "protected-#{target}-#{state}" }, as: :json
          assert_response :unprocessable_entity
          assert_match(/used by .*meeting records/i, response.parsed_body.fetch("error"))
          assert_nil response.parsed_body["deleted_dated_agenda"]
          assert_nil response.parsed_body["removed_dated_agenda_item"]
        else
          delete path
          assert_redirected_to(target == "type" ? admin_meeting_types_path : edit_admin_dated_agenda_path(@agenda))
          assert_match(/used by .*meeting records/i, flash[:alert])
          assert_nil flash[:notice]
          follow_redirect!
          assert_response :success
          assert_select ".app-flash-alert", text: /used by .*meeting records/i
        end

        assert_equal original, record_snapshot, "a refused delete must roll back every source and historical row"
        sign_in_as(@member)
        get meeting_path(@meeting)
        assert_response :success
        get meeting_minutes_path(@meeting)
        if state == "draft"
          assert_response :not_found
        else
          assert_response :success
          assert_select ".member-meeting-document", text: /Members received the community report/
          assert_select "body", text: /Private officer cue/, count: 0
          assert_equal original.fetch(:revisions), @minutes.revisions.reload.map(&:attributes)
        end
      end
    end
  end

  test "type deletion checks references created after opening the editor" do
    unused = @organization.meeting_types.create!(name: "New ceremony", position: 2, active: true)
    get edit_admin_meeting_type_path(unused)
    assert_response :success
    later_reference = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: unused, starts_at: 1.day.ago)

    assert_no_difference [ -> { MeetingType.count }, -> { Meeting.count }, -> { MeetingTypeAgendaSection.count } ] do
      delete admin_meeting_type_path(unused)
    end

    assert_redirected_to admin_meeting_types_path
    assert_match(/used by .*meeting records/i, flash[:alert])
    assert_nil flash[:notice]
    assert_equal unused.id, later_reference.reload.meeting_type_id
  end

  test "agenda deletion rolls back earlier unreferenced children before a referenced item refuses" do
    first = @agenda.dated_agenda_items.create!(title: "Unreferenced opening", position: 0, behavior_type: "scripted_ceremony", body: "Opening wording.")
    original = record_snapshot

    delete admin_dated_agenda_path(@agenda)

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal original, record_snapshot
    assert_equal "Opening wording.", first.reload.body.to_plain_text
  end

  test "item deletion checks a minutes reference added after opening the editor" do
    source = @agenda.dated_agenda_items.create!(title: "Later agenda topic", position: 3, behavior_type: "business_item")
    get edit_admin_dated_agenda_agenda_item_path(@agenda, source)
    assert_response :success
    linked = @minutes.sections.first.items.create!(source_dated_agenda_item: source, title: "Later recorded discussion", position: 3,
      behavior_type: "business_item", body: "Members discussed the later topic.")
    original = record_snapshot

    delete admin_dated_agenda_agenda_item_path(@agenda, source)

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_match(/used by .*meeting records/i, flash[:alert])
    assert_equal original, record_snapshot
    assert_equal source.id, linked.reload.source_dated_agenda_item_id
  end

  test "AI suggestion lineage also prevents item and whole agenda deletion" do
    source = @agenda.dated_agenda_items.create!(title: "Later agenda topic", position: 3, behavior_type: "business_item")
    text = "Synthetic restricted source."
    transcript = MeetingTranscript.create!(organization: @organization, meeting: @meeting, created_by: @officer,
      source_kind: "pasted_text", content: text, retention_policy: "retain_restricted", media_type: "text/plain",
      byte_size: text.bytesize, sha256_digest: Digest::SHA256.hexdigest(text))
    run = @minutes.draft_runs.create!(meeting_transcript: transcript, requested_by: @officer,
      provider: "openai", model: "synthetic-offline", reasoning_effort: "high", text_verbosity: "medium",
      prompt_version: MinutesDrafting::Prompt::VERSION, prompt_sha256: MinutesDrafting::Prompt.sha256,
      schema_version: MinutesDrafting::Prompt::SCHEMA_VERSION, source_sha256: transcript.sha256_digest,
      source_line_count: 1, status: "succeeded")
    suggestion = run.suggestions.create!(kind: "item_summary", confidence: "high", review_state: "unreviewed",
      minutes_item: @minutes.items.first, source_dated_agenda_item: source, source_start_line: 1, source_end_line: 1)
    original = record_snapshot

    [ admin_dated_agenda_agenda_item_path(@agenda, source), "/api/dated_agendas/#{@agenda.id}/items/#{source.id}",
      admin_dated_agenda_path(@agenda), "/api/dated_agendas/#{@agenda.id}" ].each do |path|
      delete path, as: path.start_with?("/api/") ? :json : :html
      if path.start_with?("/api/")
        assert_response :unprocessable_entity
        assert_match(/used by .*meeting records/i, response.parsed_body.fetch("error"))
      else
        assert_redirected_to edit_admin_dated_agenda_path(@agenda)
        assert_match(/used by .*meeting records/i, flash[:alert])
      end
      assert_equal source.id, suggestion.reload.source_dated_agenda_item_id
      assert_equal original, record_snapshot
    end
  end

  test "member delete requests cannot change a protected graph" do
    sign_in_as(@member)
    original = record_snapshot
    %w[type agenda item section api_agenda api_item].each do |target|
      delete deletion_path(target), as: target.start_with?("api_") ? :json : :html
      if target.start_with?("api_")
        assert_response :forbidden
      else
        assert_redirected_to root_path
      end
      assert_equal original, record_snapshot
    end
  end

  test "another Post's delete targets remain unavailable to the officer" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    body = other.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = other.meeting_types.create!(name: "Other template", position: 1, active: true)
    agenda = create_dated_agenda_from_template!(organization: other, meeting_body: body, meeting_type: type, starts_at: 1.week.ago)
    item = agenda.dated_agenda_items.create!(title: "Other discussion", position: 1, behavior_type: "business_item")
    original = record_snapshot
    paths = [ admin_meeting_type_path(type), admin_dated_agenda_path(agenda),
      admin_dated_agenda_agenda_item_path(agenda, item), admin_dated_agenda_agenda_section_path(agenda, agenda.default_agenda_section),
      "/api/dated_agendas/#{agenda.id}", "/api/dated_agendas/#{agenda.id}/items/#{item.id}" ]

    paths.each do |path|
      delete path, as: path.start_with?("/api/") ? :json : :html
      assert_response :not_found
      assert_equal original, record_snapshot
      assert MeetingType.exists?(type.id)
      assert DatedAgenda.exists?(agenda.id)
      assert DatedAgendaItem.exists?(item.id)
    end
  end

  private

  def create_user(name, *capabilities)
    person = Person.create!(first_name: name, last_name: "Example")
    user = User.create!(person:, email_address: "#{name.downcase}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| user.permission_grants.create!(capability:) }
    user
  end

  def deletion_path(target)
    case target
    when "type" then admin_meeting_type_path(@type)
    when "agenda" then admin_dated_agenda_path(@agenda)
    when "item" then admin_dated_agenda_agenda_item_path(@agenda, @item)
    when "section" then admin_dated_agenda_agenda_section_path(@agenda, @empty_section)
    when "api_agenda" then "/api/dated_agendas/#{@agenda.id}"
    when "api_item" then "/api/dated_agendas/#{@agenda.id}/items/#{@item.id}"
    end
  end

  def advance_minutes_to(state)
    return if state == "draft"

    @minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(
      minutes: @minutes, user: @officer, action: "attest", evidence_note: "Synthetic test attestation."))
    return if state == "attested"

    approving_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.ago)
    @minutes.record_membership_approval_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(
      minutes: @minutes, user: @officer, action: "record_membership_approval", evidence_note: "Synthetic later meeting approval.",
      action_payload: { approving_meeting_id: approving_meeting.id, disposition: "approved_as_presented" }))
  end

  def record_snapshot
    {
      type: @type.reload.attributes,
      template_items: @type.meeting_type_agenda_items.reload.map { |item| [ item.attributes, item.body.to_s, item.commander_notes.to_s ] },
      template_sections: @type.meeting_type_agenda_sections.reload.map(&:attributes),
      meeting: @meeting.reload.attributes,
      agenda: @agenda.reload.attributes,
      sections: @agenda.dated_agenda_sections.reload.map(&:attributes),
      items: @agenda.dated_agenda_items.reload.order(:id).map { |item| [ item.attributes, item.body.to_s, item.commander_notes.to_s ] },
      roll_call: @agenda.dated_agenda_items.joins(:roll_call_entries).flat_map { |item| item.roll_call_entries.map(&:attributes) },
      minutes: @minutes.reload.attributes,
      attendance: @minutes.attendance_entries.reload.map(&:attributes),
      minutes_sections: @minutes.sections.reload.map(&:attributes),
      minutes_items: @minutes.items.reload.order(:id).map { |item| [ item.attributes, item.body.to_s, item.agenda_body.to_s ] },
      outcomes: @minutes.items.flat_map { |item| item.outcomes.map(&:attributes) },
      revisions: @minutes.revisions.reload.map(&:attributes),
      attestations: @minutes.revisions.reload.filter_map { |revision| revision.attestation&.attributes },
      events: @minutes.lifecycle_events.reload.map(&:attributes),
      approval: @minutes.membership_approval&.attributes
    }
  end
end
