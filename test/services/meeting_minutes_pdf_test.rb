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

  test "filename identifies attested minutes without calling them official" do
    @minutes.update_column(:status, "attested")

    assert_equal(
      "membership-meeting-2026-07-07-attested-minutes.pdf",
      MeetingMinutesPdf.filename(minutes: @minutes)
    )
  end

  test "draft filename uses the saved minutes title after the template is renamed" do
    @minutes.update!(title: "Recorded July Meeting")
    @minutes.meeting_type.update!(name: "Renamed Template", slug: "renamed-template")

    assert_equal "recorded-july-meeting-2026-07-07-draft-minutes.pdf", MeetingMinutesPdf.filename(minutes: @minutes)
  end

  test "attested filename uses the immutable revision title" do
    adjutant = User.create!(person: Person.create!(first_name: "Test", last_name: "Adjutant"), email_address: "filename-adjutant@example.com")
    adjutant.permission_grants.create!(capability: "attest_minutes")
    @minutes.attest_with_confirmation!(confirmation: OfficialActionConfirmation.record_external!(
      minutes: @minutes, user: adjutant, action: "attest", evidence_note: "Synthetic filename attestation."
    ))
    @minutes.update_column(:title, "Changed working title")
    @minutes.meeting_type.update!(name: "Renamed Template", slug: "renamed-template")

    assert_equal "membership-meeting-2026-07-07-attested-minutes.pdf", MeetingMinutesPdf.filename(minutes: @minutes)
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
