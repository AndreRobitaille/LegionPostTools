require "test_helper"

class MeetingMinutesTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Post Hall",
      default_location_address: "165 Legion Way",
      timezone: "America/Chicago"
    )
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
  end

  test "creates a structured draft from a past meeting without an agenda" do
    meeting = create_meeting!(
      organization: @organization,
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: 1.day.ago,
      title: "September Membership Meeting"
    )

    minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)

    assert_equal meeting, minutes.meeting
    assert_equal @organization, minutes.organization
    assert_equal @meeting_body, minutes.meeting_body
    assert_equal @meeting_type, minutes.meeting_type
    assert_equal "September Membership Meeting", minutes.title
    assert_predicate minutes, :draft?
    assert_equal [ "Meeting record" ], minutes.sections.pluck(:title)
    assert_empty minutes.items
    assert_empty minutes.attendance_entries
  end

  test "seeds independent agenda snapshots and officer attendance" do
    agenda = build_agenda_with_sources
    agenda.update!(title: "Official September Agenda", location_name: "Recorded Hall")
    approver = create_user!("Approver")
    agenda.approve!(approver)
    agenda.publish!(approver)

    minutes = MeetingMinutes.create_from_meeting!(meeting: agenda.meeting)

    assert_equal "Official September Agenda", minutes.title
    assert_equal "Recorded Hall", minutes.location_name
    assert_equal agenda.dated_agenda_sections.ordered.pluck(:title), minutes.sections.pluck(:title)

    report = minutes.items.find_by!(title: "Finance report")
    source_report = agenda.dated_agenda_items.find_by!(title: "Finance report")
    assert_equal source_report.body.to_s, report.agenda_body.to_s
    assert_equal "Treasurer reported a balance.", report.agenda_body.to_plain_text.squish
    assert_predicate report.body.to_plain_text, :blank?
    assert_equal source_report, report.source_dated_agenda_item
    assert_equal @endeavor, report.endeavor
    assert_match(/\A[0-9a-f-]{36}\z/, report.record_key)

    hidden = minutes.items.find_by!(title: "Commander briefing")
    assert_predicate hidden.agenda_body.to_plain_text, :blank?
    assert_predicate hidden.body.to_plain_text, :blank?
    assert_not_includes hidden.body.to_plain_text, "Private commander cue"

    attendance = minutes.attendance_entries.order(:position)
    assert_equal 2, attendance.size
    assert_equal %w[not_recorded vacant], attendance.map(&:status)
    assert_equal [ "Adjutant", "Historian" ], attendance.map(&:office_name)

    agenda.dated_agenda_items.find_by!(title: "Finance report").body = "Changed later"
    assert_equal "Treasurer reported a balance.", report.reload.agenda_body.to_plain_text.squish
  end

  test "draft agenda supplies structure but meeting supplies the heading" do
    agenda = build_agenda_with_sources
    agenda.update!(title: "Unapproved agenda title", location_name: "Unapproved place")

    minutes = MeetingMinutes.create_from_meeting!(meeting: agenda.meeting)

    assert_equal agenda.meeting.title, minutes.title
    assert_equal agenda.meeting.location_name, minutes.location_name
    assert_equal agenda.dated_agenda_sections.count, minutes.sections.count
  end

  test "rejects a second minutes record for one meeting" do
    meeting = create_meeting!(
      organization: @organization,
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: 1.day.ago
    )
    MeetingMinutes.create_from_meeting!(meeting: meeting)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      MeetingMinutes.create_from_meeting!(meeting: meeting.reload)
    end

    assert_includes error.record.errors[:meeting], "already has a minutes record"
    assert_equal 1, MeetingMinutes.where(meeting: meeting).count
  end

  test "does not begin minutes before the meeting" do
    meeting = create_meeting!(
      organization: @organization,
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: 1.hour.from_now
    )

    error = assert_raises(ActiveRecord::RecordInvalid) do
      MeetingMinutes.create_from_meeting!(meeting: meeting)
    end

    assert_includes error.record.errors[:starts_at], "must be in the past before minutes can begin"
    assert_nil meeting.reload.minutes
  end

  test "meeting and source records cannot cross occurrence boundaries" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: past_meeting)
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "UTC")
    other_body = other_organization.meeting_bodies.create!(name: "Other", slug: "other")
    other_type = other_organization.meeting_types.create!(name: "Other Meeting", position: 1, active: true)
    other_agenda = create_dated_agenda_from_template!(
      organization: other_organization,
      meeting_body: other_body,
      meeting_type: other_type,
      starts_at: 1.day.ago
    )

    section = minutes.sections.first
    section.source_dated_agenda_section = other_agenda.default_agenda_section
    assert_not section.valid?
    assert_includes section.errors[:source_dated_agenda_section], "must belong to the same meeting"

    other_endeavor = other_organization.endeavors.create!(
      title: "Other work",
      importance: "standard",
      status: "active",
      created_by: create_user!("Other Creator")
    )
    item = section.items.new(title: "Business", behavior_type: "business_item", position: 1, endeavor: other_endeavor)
    assert_not item.valid?
    assert_includes item.errors[:endeavor], "must belong to the same organization"
  end

  test "outcomes retain explicit unknown facts" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: past_meeting)
    item = minutes.sections.first.items.create!(title: "New business", behavior_type: "business_item", position: 1)

    outcome = item.outcomes.create!(
      kind: "motion",
      text: "Purchase flags for Memorial Day",
      disposition: "not_recorded",
      position: 1
    )

    assert_equal "not_recorded", outcome.disposition
    assert_nil outcome.mover_person
    assert_nil outcome.mover_name
    assert_nil outcome.seconder_person
    assert_nil outcome.seconder_name
    assert_nil outcome.vote_summary
  end

  test "meeting cannot be deleted after minutes exist" do
    meeting = past_meeting
    MeetingMinutes.create_from_meeting!(meeting: meeting)

    assert_raises(ActiveRecord::DeleteRestrictionError) { meeting.destroy! }
    assert Meeting.exists?(meeting.id)
  end

  test "approval snapshots an exact revision and a different Adjutant can attest it" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: past_meeting)
    item = minutes.sections.first.items.create!(
      title: "Service report",
      behavior_type: "report_slot",
      position: 1,
      body: "The chair reported that twelve families received assistance."
    )
    item.outcomes.create!(kind: "decision", text: "Continue the program.", disposition: "no_vote", position: 1)
    commander = create_officer!("Casey", "Commander", "approve_minutes")
    adjutant = create_officer!("Alex", "Adjutant", "attest_minutes")
    commander_token, = AgentAccessToken.issue!(user: commander, name: "Commander agent", expires_in: 1.day)

    approval = OfficialActionConfirmation.for_delegated_agent!(
      minutes:,
      agent_access_token: commander_token,
      action: "approve"
    )
    revision = minutes.approve_with_confirmation!(confirmation: approval)

    assert_predicate minutes.reload, :approved?
    assert_equal revision, minutes.current_revision
    assert_equal "Casey Officer", revision.approver_name
    assert_equal "Commander", revision.approver_office
    assert_equal "The chair reported that twelve families received assistance.",
      ActionText::Content.new(revision.payload.dig("sections", 0, "items", 0, "body_html")).to_plain_text
    assert_equal revision.sha256, minutes.digest_for("attest")
    assert_equal "delegated_agent", minutes.lifecycle_events.last.metadata.fetch("confirmation_method")

    external = OfficialActionConfirmation.record_external!(
      minutes:,
      user: adjutant,
      action: "attest",
      evidence_note: "Written approval supplied to the recorder."
    )
    attestation = minutes.attest_with_confirmation!(confirmation: external, recorded_by: commander)

    assert_predicate minutes.reload, :attested?
    assert_equal "Alex Officer", attestation.attester_name
    assert_equal "Adjutant", attestation.attester_office
    assert_equal commander, attestation.recorded_by
    assert_equal "external_written_confirmation", minutes.lifecycle_events.last.metadata.fetch("confirmation_method")
  end

  test "approver cannot attest the same revision" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: past_meeting)
    officer = create_officer!("Dual", "Commander", "approve_minutes", "attest_minutes")
    token, = AgentAccessToken.issue!(user: officer, name: "Officer agent", expires_in: 1.day)
    minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: token, action: "approve"))
    confirmation = OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: token, action: "attest")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      minutes.attest_with_confirmation!(confirmation:)
    end

    assert_match(/different person/, error.record.errors.full_messages.to_sentence)
    assert_predicate minutes.reload, :approved?
    assert_nil minutes.current_revision.attestation
    assert_nil confirmation.reload.consumed_at
  end

  test "attested minutes can be corrected before membership approval without losing history" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: past_meeting)
    item = minutes.sections.first.items.create!(
      title: "Service report",
      behavior_type: "report_slot",
      position: 1,
      body: "Twelve families received assistance."
    )
    commander = create_officer!("Casey", "Commander", "approve_minutes", "record_minutes_approval")
    adjutant = create_officer!("Alex", "Adjutant", "attest_minutes")
    commander_token, = AgentAccessToken.issue!(user: commander, name: "Commander agent", expires_in: 1.day)
    adjutant_token, = AgentAccessToken.issue!(user: adjutant, name: "Adjutant agent", expires_in: 1.day)

    first_revision = minutes.approve_with_confirmation!(
      confirmation: OfficialActionConfirmation.for_delegated_agent!(
        minutes:,
        agent_access_token: commander_token,
        action: "approve"
      )
    )
    minutes.attest_with_confirmation!(
      confirmation: OfficialActionConfirmation.for_delegated_agent!(
        minutes:,
        agent_access_token: adjutant_token,
        action: "attest"
      )
    )

    minutes.reopen_with_confirmation!(
      confirmation: OfficialActionConfirmation.for_delegated_agent!(
        minutes:,
        agent_access_token: adjutant_token,
        action: "reopen",
        action_payload: { reason: "Incorporate the correction adopted during membership approval." }
      )
    )

    assert_predicate minutes.reload, :reopened?
    assert_equal first_revision, minutes.current_revision
    assert_equal first_revision, minutes.member_revision
    assert_equal "reopened", minutes.lifecycle_events.last.event_type
    assert_equal first_revision.id, minutes.lifecycle_events.last.metadata.fetch("superseded_revision_id")

    item.update!(body: "Thirteen families received assistance.")
    second_revision = minutes.approve_with_confirmation!(
      confirmation: OfficialActionConfirmation.for_delegated_agent!(
        minutes:,
        agent_access_token: commander_token,
        action: "approve"
      )
    )

    assert_equal 2, second_revision.number
    assert_equal first_revision, minutes.reload.member_revision,
      "the prior attested revision remains member-visible until the correction is attested"

    minutes.attest_with_confirmation!(
      confirmation: OfficialActionConfirmation.for_delegated_agent!(
        minutes:,
        agent_access_token: adjutant_token,
        action: "attest"
      )
    )
    assert_equal second_revision, minutes.reload.member_revision

    approving_meeting = create_meeting!(
      organization: @organization,
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: 1.hour.ago,
      title: "September Membership Meeting"
    )
    approval = minutes.record_membership_approval_with_confirmation!(
      confirmation: OfficialActionConfirmation.for_delegated_agent!(
        minutes:,
        agent_access_token: commander_token,
        action: "record_membership_approval",
        action_payload: {
          approving_meeting_id: approving_meeting.id,
          disposition: "approved_as_corrected"
        }
      )
    )

    assert_predicate minutes.reload, :membership_approved?
    assert_equal second_revision, approval.minutes_revision
    assert_equal approving_meeting, approval.approving_meeting
    assert_equal "Approved as corrected", approval.disposition_label
    assert_equal "membership_approved", minutes.lifecycle_events.last.event_type
    assert_equal 2, minutes.revisions.count
    assert_not approval.update(factual_note: "Changed later")
    assert_not approval.destroy
    assert_raises(ActiveRecord::RecordInvalid) do
      minutes.update!(title: "Changed after membership approval")
    end
    assert_raises(ActiveRecord::DeleteRestrictionError) { minutes.destroy! }
  end

  test "membership approval requires a later occurred meeting of the same body" do
    minutes = MeetingMinutes.create_from_meeting!(meeting: past_meeting)
    commander = create_officer!("Casey", "Commander", "approve_minutes", "record_minutes_approval")
    adjutant = create_officer!("Alex", "Adjutant", "attest_minutes")
    commander_token, = AgentAccessToken.issue!(user: commander, name: "Commander agent", expires_in: 1.day)
    adjutant_token, = AgentAccessToken.issue!(user: adjutant, name: "Adjutant agent", expires_in: 1.day)
    minutes.approve_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: commander_token, action: "approve"))
    minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.for_delegated_agent!(minutes:, agent_access_token: adjutant_token, action: "attest"))
    future_meeting = create_meeting!(
      organization: @organization,
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: 1.day.from_now
    )
    confirmation = OfficialActionConfirmation.for_delegated_agent!(
      minutes:,
      agent_access_token: commander_token,
      action: "record_membership_approval",
      action_payload: {
        approving_meeting_id: future_meeting.id,
        disposition: "approved_as_presented"
      }
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      minutes.record_membership_approval_with_confirmation!(confirmation:)
    end
    assert_predicate minutes.reload, :attested?
    assert_nil minutes.membership_approval
    assert_nil confirmation.reload.consumed_at
  end

  private

  def past_meeting
    create_meeting!(
      organization: @organization,
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: 1.day.ago
    )
  end

  def create_user!(name)
    person = Person.create!(first_name: name, last_name: "Officer")
    User.create!(person: person, email_address: "#{name.parameterize}-#{SecureRandom.hex(3)}@example.com")
  end

  def create_officer!(first_name, office, *capabilities)
    user = create_user!(first_name)
    title = @organization.position_titles.find_or_create_by!(name: office) do |position|
      position.display_order = @organization.position_titles.count + 1
      position.active = true
    end
    title.position_assignments.create!(person: user.person, starts_on: 1.year.ago.to_date)
    capabilities.each { |capability| user.permission_grants.create!(capability:) }
    user
  end

  def build_agenda_with_sources
    meeting = create_meeting!(
      organization: @organization,
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: 1.day.ago,
      title: "September Membership Meeting",
      location_name: "Meeting Hall"
    )
    agenda = DatedAgenda.create_from_template!(meeting: meeting)
    section = agenda.default_agenda_section
    section.update!(title: "Reports")

    creator = create_user!("Endeavor Creator")
    @endeavor = @organization.endeavors.create!(
      title: "Memorial grounds",
      importance: "standard",
      status: "active",
      created_by: creator
    )

    report_catalog = @organization.agenda_item_catalog_entries.create!(
      title: "Finance report",
      category: "reports",
      behavior_type: "report_slot",
      position: 1,
      active: true,
      show_wording_in_minutes: true,
      body: "Treasurer reported a balance."
    )
    report = DatedAgendaItem.create_from_catalog_entry!(
      report_catalog,
      dated_agenda: agenda,
      agenda_section: section,
      position: 1
    )
    report.update!(endeavor: @endeavor)

    hidden_catalog = @organization.agenda_item_catalog_entries.create!(
      title: "Commander briefing",
      category: "reports",
      behavior_type: "report_slot",
      position: 2,
      active: true,
      show_wording_in_minutes: false,
      body: "Do not seed this wording.",
      commander_notes: "Private commander cue"
    )
    DatedAgendaItem.create_from_catalog_entry!(
      hidden_catalog,
      dated_agenda: agenda,
      agenda_section: section,
      position: 2
    )

    adjutant = @organization.position_titles.create!(name: "Adjutant", display_order: 1, active: true, required_by_default: true)
    historian = @organization.position_titles.create!(name: "Historian", display_order: 2, active: true, required_by_default: true)
    person = Person.create!(first_name: "Alex", last_name: "Adjutant")
    adjutant.position_assignments.create!(person: person, starts_on: 1.year.ago.to_date)
    assert historian.position_assignments.empty?

    roll_call_catalog = @organization.agenda_item_catalog_entries.create!(
      title: "Officer roll call",
      category: "call_to_order",
      behavior_type: "roll_call",
      position: 3,
      active: true
    )
    DatedAgendaItem.create_from_catalog_entry!(
      roll_call_catalog,
      dated_agenda: agenda,
      agenda_section: section,
      position: 3
    )

    agenda
  end
end
