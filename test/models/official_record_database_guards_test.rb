require "test_helper"

class OfficialRecordDatabaseGuardsTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    person = Person.create!(first_name: "Synthetic", last_name: "Adjutant")
    @officer = User.create!(person:, email_address: "guard-adjutant@example.com", email_verified_at: Time.current)
    %w[attest_minutes record_minutes_approval].each { |capability| @officer.permission_grants.create!(capability:) }
    meeting = create_meeting!(organization:, meeting_body: body, starts_at: 2.weeks.ago, title: "Recorded meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting:)
    @minutes.sections.first.items.create!(title: "Community report", behavior_type: "report_slot", position: 1, body: "Members received the report.")
    @minutes.attest_with_confirmation!(confirmation: confirmation("attest"))
    approving_meeting = create_meeting!(organization:, meeting_body: body, starts_at: 1.week.ago, title: "Later membership meeting")
    @minutes.record_membership_approval_with_confirmation!(confirmation: confirmation("record_membership_approval",
      approving_meeting_id: approving_meeting.id, disposition: "approved_as_presented"))
    @records = {
      "minutes" => @minutes,
      "revision" => @minutes.current_revision,
      "attestation" => @minutes.current_revision.attestation,
      "event" => @minutes.lifecycle_events.first,
      "membership_approval" => @minutes.membership_approval
    }
  end

  %w[minutes revision attestation event membership_approval].each do |name|
    %w[update delete].each do |operation|
      test "database rejects direct #{operation} of official #{name}" do
        record = @records.fetch(name)
        original = record.reload.attributes
        error = assert_raises(ActiveRecord::StatementInvalid) do
          record.class.transaction(requires_new: true) do
            scope = record.class.where(id: record.id)
            if operation == "update"
              scope.update_all(updated_at: 1.day.from_now)
            else
              scope.delete_all
            end
          end
        end

        expected = name == "minutes" ? "membership-approved minutes are immutable" : "official minutes records are append-only"
        assert_includes error.message, expected, "a foreign-key failure is not proof of the immutability guard"
        assert_equal original, record.reload.attributes
      end
    end
  end

  test "fresh preparation preserves every existing custom database guard" do
    expected = %w[
      endeavor_history_editions_immutable endeavor_history_events_immutable endeavor_history_guidances_immutable
      endeavor_history_results_immutable endeavor_history_run_protected endeavor_source_links_immutable
      meeting_minutes_final_context_lock meeting_minutes_membership_approved_immutable meetings_final_context_immutable
      minutes_attestations_append_only minutes_lifecycle_events_append_only
      minutes_membership_approvals_append_only minutes_revisions_append_only
    ]
    actual = ActiveRecord::Base.connection.select_values("SELECT tgname FROM pg_trigger WHERE NOT tgisinternal ORDER BY tgname")

    assert_equal expected.sort, actual, "schema preparation must preserve the migration-defined guards"
  end

  test "database permits a legitimate working draft update" do
    meeting = create_meeting!(organization: @minutes.organization, meeting_body: @minutes.meeting_body, starts_at: 1.day.ago)
    draft = MeetingMinutes.create_from_meeting!(meeting:)

    assert_equal 1, MeetingMinutes.where(id: draft.id).update_all(title: "Corrected draft heading")
    assert_equal "Corrected draft heading", draft.reload.title
    assert_equal "draft", draft.status
    assert_equal "membership_approved", @minutes.reload.status
  end

  private

  def confirmation(action, payload = {})
    OfficialActionConfirmation.record_external!(minutes: @minutes, user: @officer, action:, action_payload: payload,
      evidence_note: "Synthetic database guard test confirmation.")
  end
end
