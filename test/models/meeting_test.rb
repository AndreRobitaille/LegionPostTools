require "test_helper"

class MeetingTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(
      name: "Test Post",
      unit_type: "american_legion_post",
      default_location_name: "Legion Hall",
      default_location_address: "123 Main Street",
      timezone: "America/Chicago"
    )
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
  end

  test "defaults title and snapshots the body's effective place" do
    meeting = @organization.meetings.create!(meeting_body: @body, meeting_type: @type, starts_at: Time.zone.local(2026, 9, 8, 19))

    assert_equal "Membership Meeting — 08 SEP 2026", meeting.title
    assert_equal "Legion Hall", meeting.location_name
    assert_equal "123 Main Street", meeting.location_address

    @organization.update!(default_location_name: "Changed Hall")
    assert_equal "Legion Hall", meeting.reload.location_name
  end

  test "associations must belong to the same organization" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_body = other.meeting_bodies.create!(name: "Membership", slug: "other-membership")

    meeting = @organization.meetings.new(meeting_body: other_body, starts_at: 1.week.from_now, location_name: "Hall")

    assert_not meeting.valid?
    assert_includes meeting.errors[:meeting_body], "must belong to the same organization"
  end

  test "blank title is regenerated when the meeting date changes" do
    meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: Time.zone.local(2026, 9, 8, 19), title: "Custom title")

    meeting.update!(title: "", starts_at: Time.zone.local(2026, 10, 6, 19))

    assert_equal "Membership Meeting — 06 OCT 2026", meeting.title
  end

  test "ordinary meeting updates synchronize draft agenda snapshots" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now, location_name: "Original Hall")

    agenda.meeting.update!(location_name: "Changed Hall")

    assert_equal "Changed Hall", agenda.reload.location_name
  end

  test "ordinary meeting updates respect official agenda boundaries" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @body, meeting_type: @type, starts_at: 1.week.from_now, location_name: "Original Hall")
    approver = User.create!(
      person: Person.create!(first_name: "Approval", last_name: "Officer"),
      email_address: "approval@example.com",
      email_verified_at: Time.current
    )
    agenda.approve!(approver)

    assert_not agenda.meeting.update(location_name: "Changed Hall")
    assert_includes agenda.meeting.errors[:base], "Reopen the agenda before changing this meeting's date, title, or place."
    assert_equal "Original Hall", agenda.meeting.reload.location_name
  end
end
