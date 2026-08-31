require "test_helper"

class MeetingMinutesPdfTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    meeting_body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting_type = organization.meeting_types.create!(
      name: "Membership Meeting",
      slug: "membership-meeting",
      position: 1,
      active: true
    )
    meeting = create_meeting!(
      organization:,
      meeting_body:,
      meeting_type:,
      starts_at: Time.zone.local(2026, 7, 7, 19, 0)
    )
    @minutes = MeetingMinutes.create_from_meeting!(meeting:)
  end

  test "builds a descriptive draft filename" do
    assert_equal(
      "membership-meeting-2026-07-07-draft-minutes.pdf",
      MeetingMinutesPdf.filename(minutes: @minutes)
    )
  end

  test "signed source token fixes the organization and minutes record" do
    token = MeetingMinutesPdf.source_token(minutes: @minutes)

    assert_equal(
      {
        "organization_id" => @minutes.organization_id,
        "meeting_minutes_id" => @minutes.id
      },
      MeetingMinutesPdf.verify_source_token!(token)
    )
  end
end
