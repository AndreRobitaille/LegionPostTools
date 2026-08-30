require "test_helper"
require Rails.root.join("db/migrate/20260830020000_reinterpret_legacy_dated_agenda_times")

class ReinterpretLegacyDatedAgendaTimesTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(
      name: "Migration Test Post",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    meeting_body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting_type = organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    @agenda = organization.dated_agendas.create!(
      meeting_body: meeting_body,
      meeting_type: meeting_type,
      starts_at: Time.utc(2026, 7, 7, 18, 30),
      title: "Membership Meeting — 07 JUL 2026",
      status: "published"
    )
    @agenda.update_columns(
      starts_at: Time.utc(2026, 7, 7, 18, 30),
      updated_at: Time.utc(2026, 8, 30, 2, 25),
      lock_version: 7
    )

    @migration = ReinterpretLegacyDatedAgendaTimes.new
  end

  test "reinterprets the legacy UTC components in the organization's zone" do
    @migration.suppress_messages { @migration.up }

    assert_equal Time.utc(2026, 7, 7, 23, 30), @agenda.reload.starts_at.utc
    assert_equal "2026-07-07 18:30:00 CDT", @agenda.starts_at.in_time_zone("America/Chicago").strftime("%F %T %Z")
    assert_equal Time.utc(2026, 8, 30, 2, 25), @agenda.updated_at.utc
    assert_equal 7, @agenda.lock_version
    assert_equal "published", @agenda.status
  end

  test "down restores the prior UTC-wall representation" do
    @migration.suppress_messages do
      @migration.up
      @migration.down
    end

    assert_equal Time.utc(2026, 7, 7, 18, 30), @agenda.reload.starts_at.utc
    assert_equal Time.utc(2026, 8, 30, 2, 25), @agenda.updated_at.utc
    assert_equal 7, @agenda.lock_version
  end
end
