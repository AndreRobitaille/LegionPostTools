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
