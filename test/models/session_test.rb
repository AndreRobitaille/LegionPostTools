require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Test American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    meeting = create_meeting!(organization:, meeting_body: body, starts_at: 1.day.ago)
    @minutes = MeetingMinutes.create_from_meeting!(meeting:)
    @user = User.create!(person: Person.create!(first_name: "Test", last_name: "Commander"), email_address: "commander@example.com")
    @user.permission_grants.create!(capability: "approve_minutes")
    @session_record = Session.create!(user: @user, authenticated_at: Time.current, last_seen_at: Time.current)
    @confirmation = OfficialActionConfirmation.prepare!(minutes: @minutes, user: @user, session: @session_record, action: "approve")
  end

  test "ending a session preserves the completed approval and its audit records" do
    @confirmation.confirm!(session: @session_record)
    revision = @minutes.approve_with_confirmation!(confirmation: @confirmation)
    event = @minutes.lifecycle_events.sole
    confirmation_attributes = @confirmation.reload.attributes.except("session_id")
    revision_attributes = revision.attributes
    event_attributes = event.attributes

    assert_difference -> { Session.count }, -1 do
      @session_record.destroy!
    end

    assert_nil @confirmation.reload.session_id
    assert_equal confirmation_attributes, @confirmation.attributes.except("session_id")
    assert_equal revision_attributes, revision.reload.attributes
    assert_equal event_attributes, event.reload.attributes
    assert_equal @confirmation, event.official_action_confirmation
    assert_predicate @minutes.reload, :approved?
  end

  test "detached in-app confirmations cannot be confirmed or consumed without a session or after signing in again" do
    @confirmation.confirm!(session: @session_record)
    @session_record.destroy!
    @confirmation.reload
    replacement_session = Session.create!(user: @user, authenticated_at: Time.current)

    [ nil, replacement_session ].each do |session_record|
      assert_not @confirmation.usable_by?(user: @user, session: session_record)
      assert_raises(ActiveRecord::RecordInvalid) { @confirmation.confirm!(session: session_record) }
    end

    [ nil, replacement_session ].each do |session_record|
      assert_raises(ActiveRecord::RecordInvalid) do
        @confirmation.consume!(user: @user, session: session_record) { flunk "Detached confirmation authorized an action" }
      end
    end
    assert_nil @confirmation.reload.consumed_at
    assert_predicate @minutes.reload, :draft?
  end

  test "detached email reauthentication challenges cannot be consumed without a session or after signing in again" do
    challenge = MagicLink.create_for!(@user, purpose: "official_minutes_action", session: @session_record)
    @session_record.destroy!
    assert_nil challenge.reload.session_id
    replacement_session = Session.create!(user: @user, authenticated_at: Time.current)

    [ nil, replacement_session ].each do |session_record|
      assert_nil MagicLink.consume!(challenge.token, purpose: challenge.purpose, session: session_record)
      assert_nil MagicLink.consume_code!(
        browser_challenge: challenge.browser_challenge, code: challenge.login_code,
        purpose: challenge.purpose, session: session_record
      )
    end
    assert_nil challenge.reload.used_at
  end
end
