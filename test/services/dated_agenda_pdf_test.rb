require "test_helper"

class DatedAgendaPdfTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    meeting_body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting_type = organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    @agenda = create_dated_agenda!(organization: organization,
      meeting_body:,
      meeting_type:,
      starts_at: Time.zone.local(2026, 7, 7, 19, 0),
      title: "Membership Meeting — July 7, 2026",
      status: "draft"
    )
  end

  test "builds descriptive filenames for both document variants" do
    assert_equal "membership-meeting-2026-07-07-agenda.pdf", DatedAgendaPdf.filename(dated_agenda: @agenda, variant: "agenda")
    assert_equal "membership-meeting-2026-07-07-officer-notes.pdf", DatedAgendaPdf.filename(dated_agenda: @agenda, variant: "officer_notes")
  end

  test "signed source token fixes the organization agenda and variant" do
    token = DatedAgendaPdf.source_token(dated_agenda: @agenda, variant: "officer_notes")

    assert_equal(
      {
        "organization_id" => @agenda.organization_id,
        "dated_agenda_id" => @agenda.id,
        "variant" => "officer_notes"
      },
      DatedAgendaPdf.verify_source_token!(token)
    )
  end

  test "rejects unknown document variants" do
    assert_raises(ArgumentError) do
      DatedAgendaPdf.filename(dated_agenda: @agenda, variant: "minutes")
    end
  end
end
