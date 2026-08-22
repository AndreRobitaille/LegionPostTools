require "test_helper"

class AgentAccessTokenTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Doe"), email_address: "jane@example.com")
  end

  test "issues a recognizable token once and stores only its digest" do
    token, plaintext = AgentAccessToken.issue!(user: @user, name: "Grok Agent Computer", expires_in: 90.days)

    assert_match(/\Alpt_[A-Za-z0-9_-]+_[A-Za-z0-9_-]+\z/, plaintext)
    assert_equal token.id, AgentAccessToken.authenticate(plaintext)&.id
    assert_not_includes token.attributes.values, plaintext
    assert_not_includes token.attributes.values, plaintext.split("_").last
    assert_match(/\A\w{4}\z/, token.display_hint)
    assert_not_equal plaintext.split("_").last, token.reload.secret_digest
  end

  test "rejects malformed expired revoked and disabled credentials" do
    token, plaintext = AgentAccessToken.issue!(user: @user, name: "Routine", expires_in: 30.days)

    assert_nil AgentAccessToken.authenticate("not-a-token")
    token.update!(expires_at: 1.minute.ago)
    assert_nil AgentAccessToken.authenticate(plaintext)

    token.update!(expires_at: 1.day.from_now, revoked_at: Time.current)
    assert_nil AgentAccessToken.authenticate(plaintext)

    token.update!(revoked_at: nil)
    @user.update!(disabled_at: Time.current)
    assert_nil AgentAccessToken.authenticate(plaintext)
  end

  test "revocation takes effect on the next lookup" do
    token, plaintext = AgentAccessToken.issue!(user: @user, name: "Routine", expires_in: 30.days)

    assert_equal token, AgentAccessToken.authenticate(plaintext)
    token.revoke!(@user)
    assert_nil AgentAccessToken.authenticate(plaintext)
    assert_equal @user, token.reload.revoked_by
  end

  test "last use writes are throttled" do
    token, plaintext = AgentAccessToken.issue!(user: @user, name: "Routine", expires_in: 30.days)
    token.update!(last_used_at: 5.minutes.ago)

    assert_no_changes -> { token.reload.last_used_at } do
      AgentAccessToken.authenticate(plaintext)
    end

    token.update!(last_used_at: 16.minutes.ago)
    assert_changes -> { token.reload.last_used_at } do
      AgentAccessToken.authenticate(plaintext)
    end
  end
end
