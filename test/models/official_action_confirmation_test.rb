require "test_helper"

class OfficialActionConfirmationTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Test American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: 1.day.ago, title: "Recorded membership meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting:)
    @item = @minutes.sections.first.items.create!(title: "Service report", behavior_type: "report_slot", position: 1,
      body: "Twelve families received assistance.")
    @user = create_user!("Adjutant")
    @user.permission_grants.create!(capability: "attest_minutes")
    @session = Session.create!(user: @user, authenticated_at: Time.current)
    @other_session = Session.create!(user: @user, authenticated_at: Time.current)
    @other_user = create_user!("Other")
    @token, = AgentAccessToken.issue!(user: @user, name: "Synthetic officer agent", expires_in: 1.day)
  end

  test "all provenance factories save an independent ten minute lifetime and identity" do
    freeze_time do
      confirmations = [ in_app_confirmation, delegated_confirmation, external_confirmation ]

      confirmations.each do |confirmation|
        assert_equal Time.current + 600.seconds, confirmation.reload.expires_at
        assert_equal @user.id, confirmation.user_id
        assert_equal @minutes.id, confirmation.meeting_minutes_id
        assert_equal "attest", confirmation.action
        assert_equal @minutes.lock_version, confirmation.record_lock_version
        assert_equal @minutes.digest_for("attest"), confirmation.content_digest
        assert_nil confirmation.consumed_at
      end
      assert_equal "in_app", confirmations[0].confirmation_method
      assert_equal @session.id, confirmations[0].session_id
      assert_nil confirmations[0].confirmed_at
      assert_equal "delegated_agent", confirmations[1].confirmation_method
      assert_equal @token.id, confirmations[1].agent_access_token_id
      assert_equal Time.current, confirmations[1].confirmed_at
      assert_nil confirmations[1].session_id
      assert_equal "external_written_confirmation", confirmations[2].confirmation_method
      assert_equal "Synthetic signed written confirmation.", confirmations[2].evidence_note
      assert_equal Time.current, confirmations[2].confirmed_at
      assert_nil confirmations[2].session_id
    end
  end

  test "in app confirmation completes the actual attestation before expiry" do
    freeze_time do
      confirmation = in_app_confirmation
      travel 9.minutes
      confirmation.confirm!(session: @session)

      assert_saved_attestation(confirmation)
      assert_equal Time.current, confirmation.reload.confirmed_at
      assert_equal Time.current, confirmation.consumed_at
    end
  end

  test "expired unconfirmed identity remains unchanged and a fresh confirmation succeeds" do
    freeze_time do
      expired = in_app_confirmation
      original = saved_graph
      travel 601.seconds

      assert_raises(ActiveRecord::RecordInvalid) { expired.confirm!(session: @session) }
      assert_equal original, saved_graph
      assert_nil expired.reload.confirmed_at
      assert_nil expired.consumed_at

      fresh = in_app_confirmation
      fresh.confirm!(session: @session)
      assert_saved_attestation(fresh)
      assert_nil expired.reload.confirmed_at
      assert_nil expired.consumed_at
    end
  end

  test "expired confirmed actions preserve every stored row for all provenance methods" do
    freeze_time do
      in_app = in_app_confirmation
      in_app.confirm!(session: @session)
      expired = [ in_app, delegated_confirmation, external_confirmation ]
      original = saved_graph
      travel 601.seconds

      expired.each do |confirmation|
        assert_raises(ActiveRecord::RecordInvalid) { @minutes.attest_with_confirmation!(confirmation:) }
        assert_equal original, saved_graph
        assert_nil confirmation.reload.consumed_at
      end

      fresh = in_app_confirmation
      fresh.confirm!(session: @session)
      assert_saved_attestation(fresh)
      expired.each { |confirmation| assert_nil confirmation.reload.consumed_at }
    end
  end

  test "wrong live user or session cannot consume a confirmed action before the correct session succeeds" do
    confirmation = in_app_confirmation
    confirmation.confirm!(session: @session)
    original = saved_graph

    [ [ @other_user, @session ], [ @user, @other_session ], [ @user, nil ] ].each do |user, session|
      assert_raises(ActiveRecord::RecordInvalid) do
        confirmation.consume!(user:, session:) { @minutes.attest_with_confirmation!(confirmation:) }
      end
      assert_equal original, saved_graph
    end

    assert_saved_attestation(confirmation)
  end

  test "a consumed confirmation never yields again or changes the completed official graph" do
    confirmation = in_app_confirmation
    confirmation.confirm!(session: @session)
    assert_saved_attestation(confirmation)
    original = saved_graph
    yielded = false

    assert_raises(ActiveRecord::RecordInvalid) do
      confirmation.consume!(user: @user, session: @session) { yielded = true }
    end
    assert_not yielded
    assert_equal original, saved_graph
    assert_raises(ActiveRecord::RecordInvalid) { @minutes.attest_with_confirmation!(confirmation:) }
    assert_equal original, saved_graph
  end

  test "a failure after actual attestation writes rolls back all rows and the same confirmation can recover" do
    confirmation = in_app_confirmation
    confirmation.confirm!(session: @session)
    original = saved_graph
    record_event = @minutes.method(:record_lifecycle_event!)
    minutes = @minutes
    test_case = self
    reached_persisted_action = false
    failed_event = lambda do |**attributes|
      record_event.call(**attributes)
      test_case.assert_predicate minutes.reload, :attested?
      test_case.assert_equal 1, minutes.revisions.count
      test_case.assert_not_nil minutes.current_revision.attestation.id
      test_case.assert_equal "attested", minutes.lifecycle_events.sole.event_type
      test_case.assert_nil confirmation.reload.consumed_at
      reached_persisted_action = true
      raise ActiveRecord::RecordInvalid, minutes
    end

    @minutes.define_singleton_method(:record_lifecycle_event!, failed_event)
    begin
      assert_raises(ActiveRecord::RecordInvalid) { @minutes.attest_with_confirmation!(confirmation:) }
    ensure
      @minutes.singleton_class.remove_method(:record_lifecycle_event!)
    end
    assert reached_persisted_action
    assert_equal original, saved_graph
    assert_nil confirmation.reload.consumed_at

    assert_saved_attestation(confirmation)
  end

  private

  def in_app_confirmation
    OfficialActionConfirmation.prepare!(minutes: @minutes, user: @user, session: @session, action: "attest")
  end

  def delegated_confirmation
    OfficialActionConfirmation.for_delegated_agent!(minutes: @minutes, agent_access_token: @token, action: "attest")
  end

  def external_confirmation
    OfficialActionConfirmation.record_external!(minutes: @minutes, user: @user, action: "attest",
      evidence_note: "Synthetic signed written confirmation.")
  end

  def assert_saved_attestation(confirmation)
    attestation = @minutes.attest_with_confirmation!(confirmation:)
    assert_predicate @minutes.reload, :attested?
    revision = @minutes.current_revision
    assert_equal "Recorded membership meeting", revision.payload.fetch("title")
    assert_includes revision.payload.to_json, "Twelve families received assistance."
    assert_equal @user.id, attestation.reload.attested_by_id
    assert_equal @user.id, attestation.recorded_by_id
    assert_equal confirmation.id, attestation.official_action_confirmation_id
    assert_equal revision.id, attestation.minutes_revision_id
    event = @minutes.lifecycle_events.sole
    assert_equal confirmation.id, event.official_action_confirmation_id
    assert_equal @user.id, event.actor_id
    assert_equal revision.id, event.minutes_revision_id
    assert_equal "in_app", event.metadata.fetch("confirmation_method")
    assert_not_nil confirmation.reload.consumed_at
    assert_equal "Twelve families received assistance.", @item.reload.body.to_plain_text
  end

  def saved_graph
    revisions = @minutes.revisions.order(:id)
    [ @minutes.reload.attributes, @minutes.revision_payload,
      @minutes.sections.order(:id).map(&:attributes), @minutes.items.order(:id).map(&:attributes),
      @minutes.attendance_entries.order(:id).map(&:attributes), revisions.map(&:attributes),
      MinutesAttestation.where(minutes_revision_id: revisions.select(:id)).order(:id).map(&:attributes),
      @minutes.lifecycle_events.order(:id).map(&:attributes), @minutes.membership_approval&.attributes,
      OfficialActionConfirmation.where(meeting_minutes: @minutes).order(:id).map(&:attributes),
      @item.reload.body.to_plain_text ]
  end

  def create_user!(name)
    User.create!(person: Person.create!(first_name: name, last_name: "Officer"),
      email_address: "#{name.downcase}@example.com", email_verified_at: Time.current)
  end
end
