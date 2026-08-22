require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Doe"), email_address: "jane@example.com")
  end

  test "creates independent link code and browser challenge without persisting plaintext" do
    magic_link = MagicLink.create_for!(@user)

    assert_match(/\A\d{8}\z/, magic_link.login_code)
    assert_operator magic_link.browser_challenge.length, :>=, 40
    assert_operator magic_link.token.length, :>=, 40
    assert_not_equal magic_link.token, magic_link.browser_challenge
    assert_not_includes magic_link.attributes.values, magic_link.login_code
    assert_not_includes magic_link.attributes.values, magic_link.browser_challenge
    assert_not_includes magic_link.attributes.values, magic_link.token
  end

  test "fresh unused token can be consumed once and invalidates the code" do
    magic_link = MagicLink.create_for!(@user)

    assert_equal @user, MagicLink.consume!(magic_link.token)
    assert_nil MagicLink.consume!(magic_link.token)
    assert_nil MagicLink.consume_code!(browser_challenge: magic_link.browser_challenge, code: magic_link.login_code)
    assert_not_nil magic_link.reload.used_at
  end

  test "matching browser challenge accepts grouped code once and invalidates link" do
    magic_link = MagicLink.create_for!(@user)
    grouped_code = magic_link.login_code.insert(4, " ")

    assert_equal @user, MagicLink.consume_code!(browser_challenge: magic_link.browser_challenge, code: grouped_code)
    assert_nil MagicLink.consume_code!(browser_challenge: magic_link.browser_challenge, code: grouped_code)
    assert_nil MagicLink.consume!(magic_link.token)
  end

  test "code accepts one hyphen separator" do
    magic_link = MagicLink.create_for!(@user)
    grouped_code = magic_link.login_code.insert(4, "-")

    assert_equal @user, MagicLink.consume_code!(browser_challenge: magic_link.browser_challenge, code: grouped_code)
  end

  test "wrong or missing browser challenge cannot consume code" do
    magic_link = MagicLink.create_for!(@user)

    assert_nil MagicLink.consume_code!(browser_challenge: SecureRandom.urlsafe_base64(32), code: magic_link.login_code)
    assert_nil MagicLink.consume_code!(browser_challenge: nil, code: magic_link.login_code)
    assert_nil magic_link.reload.used_at
  end

  test "five wrong attempts exhaust the challenge" do
    magic_link = MagicLink.create_for!(@user)

    5.times do |attempt|
      assert_nil MagicLink.consume_code!(browser_challenge: magic_link.browser_challenge, code: format("%08d", attempt))
    end

    assert_equal 5, magic_link.reload.failed_attempts
    assert_nil MagicLink.consume_code!(browser_challenge: magic_link.browser_challenge, code: magic_link.login_code)
  end

  test "expired token cannot be consumed" do
    magic_link = MagicLink.create_for!(@user)
    magic_link.update!(expires_at: 1.minute.ago)

    assert_nil MagicLink.consume!(magic_link.token)
    assert_nil MagicLink.consume_code!(browser_challenge: magic_link.browser_challenge, code: magic_link.login_code)
  end

  test "disabled user cannot consume token" do
    magic_link = MagicLink.create_for!(@user)
    @user.update!(disabled_at: Time.current)

    assert_nil MagicLink.consume!(magic_link.token)
    assert_nil MagicLink.consume_code!(browser_challenge: magic_link.browser_challenge, code: magic_link.login_code)
    assert_nil magic_link.reload.used_at
  end


  test "reauthentication challenges are bound to purpose and session" do
    session_record = Session.create!(user: @user, authenticated_at: 1.hour.ago, last_seen_at: Time.current)
    other_session = Session.create!(user: @user, authenticated_at: 1.hour.ago, last_seen_at: Time.current)
    challenge = MagicLink.create_for!(
      @user, purpose: "create_agent_access_token", session: session_record
    )

    assert_nil MagicLink.consume!(challenge.token)
    assert_nil MagicLink.consume_code!(
      browser_challenge: challenge.browser_challenge,
      code: challenge.login_code,
      purpose: "sign_in"
    )
    assert_nil MagicLink.consume_code!(
      browser_challenge: challenge.browser_challenge,
      code: challenge.login_code,
      purpose: "create_agent_access_token",
      session: other_session
    )
    assert_equal @user, MagicLink.consume_code!(
      browser_challenge: challenge.browser_challenge,
      code: challenge.login_code,
      purpose: "create_agent_access_token",
      session: session_record
    )
  end
end
