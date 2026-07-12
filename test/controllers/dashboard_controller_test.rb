require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication after setup" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Installation.singleton.update!(setup_completed_at: Time.current)

    get root_path

    assert_redirected_to new_session_path
  end

  test "partial setup state still redirects to setup" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    get root_path

    assert_redirected_to new_setup_path
  end

  test "true first run root redirects to setup" do
    get root_path

    assert_redirected_to new_setup_path
  end

  test "user only partial setup root redirects to setup" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)

    get root_path

    assert_redirected_to new_setup_path
  end

  test "recovery installed state unauthenticated root redirects to sign in" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)

    get root_path

    assert_redirected_to new_session_path
  end

  test "authenticated user sees dashboard" do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Andre", last_name: "Robitaille")
    user = User.create!(person: person, email_address: "andre@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Installation.singleton.update!(setup_completed_at: Time.current)
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "h1", organization.name
    assert_match "Signed in as #{person.full_name}", response.body
  end

  test "signed in user in recovery installed state can reach dashboard" do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Andre", last_name: "Robitaille")
    user = User.create!(person: person, email_address: "andre@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "h1", organization.name
    assert_match "Signed in as #{person.full_name}", response.body
  end

  test "stale sessions older than 180 days are expired" do
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    stale_session = Session.create!(
      user: user,
      ip_address: "127.0.0.1",
      user_agent: "test",
      last_seen_at: 181.days.ago
    )

    set_session_cookie(stale_session)

    get root_path

    assert_redirected_to new_session_path
    assert_nil Session.find_by(id: stale_session.id)
  end

  test "active resumed sessions update last seen periodically" do
    Installation.singleton.update!(setup_completed_at: Time.current)
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Andre", last_name: "Robitaille")
    user = User.create!(person: person, email_address: "andre@example.com", email_verified_at: Time.current)
    active_session = Session.create!(
      user: user,
      ip_address: "127.0.0.1",
      user_agent: "test",
      last_seen_at: 2.hours.ago
    )

    set_session_cookie(active_session)

    get root_path

    active_session.reload

    assert_response :success
    assert_equal organization.name, response.parsed_body.at("h1").text
    assert active_session.last_seen_at > 10.minutes.ago
  end

  test "shows the passkey invite when the user has no passkeys" do
    user = signed_in_member
    get root_path
    assert_response :success
    assert_match "Add a passkey", response.body
  end

  test "hides the passkey invite when the user already has a passkey" do
    user = signed_in_member
    PasskeyCredential.create!(user: user, external_id: "cid", public_key: "pk", sign_count: 0)
    get root_path
    assert_response :success
    assert_no_match "Add a passkey", response.body
  end

  test "shows roster email review prompt when needed" do
    user = signed_in_member
    user.person.update!(roster_email_address: "roster@example.com")
    user.update!(email_address: "login@example.com")

    get root_path

    assert_response :success
    assert_select "h2", "Review your login email"
  end

  test "remind later does not show the roster email review prompt again in the same session" do
    user = signed_in_member
    user.person.update!(roster_email_address: "roster@example.com")
    user.update!(email_address: "login@example.com")

    patch roster_email_review_path, params: { decision: "remind_later" }

    assert_redirected_to root_path

    get root_path

    assert_response :success
    assert_no_match "Review your login email", response.body
  end

  test "remind later shows the roster email review prompt again in a new signed-in session" do
    user = signed_in_member
    user.person.update!(roster_email_address: "roster@example.com")
    user.update!(email_address: "login@example.com")

    patch roster_email_review_path, params: { decision: "remind_later" }

    assert_redirected_to root_path

    open_session do |new_session|
      new_session.sign_in_as(user)
      new_session.get root_path

      new_session.assert_response :success
      new_session.assert_select "h2", "Review your login email"
    end
  end

  test "does not show roster email review prompt when roster and login emails match" do
    user = signed_in_member
    user.person.update!(roster_email_address: "jane@example.com")

    get root_path

    assert_response :success
    assert_no_match "Review your login email", response.body
  end

  test "invite stays hidden after dismissal within the session" do
    signed_in_member
    delete passkey_invitation_path
    assert_redirected_to root_path

    get root_path
    assert_response :success
    assert_no_match "Add a passkey", response.body
  end

  private

  # A fully set-up, signed-in member with no passkeys yet.
  def signed_in_member
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Installation.singleton.update!(setup_completed_at: Time.current)
    sign_in_as(user)
    user
  end

  def set_session_cookie(session_record)
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session_record.id
    cookies[:session_id] = jar["session_id"]
  end
end
