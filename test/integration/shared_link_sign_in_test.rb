require "test_helper"

class SharedLinkSignInTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Synthetic American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Member"), email_address: "member@example.test")
    @grant = @user.permission_grants.create!(capability: "manage_agendas")
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @agenda = create_dated_agenda!(organization: @organization, meeting_body: body, meeting_type: type, starts_at: 1.week.from_now, title: "Synthetic Shared Agenda")
    @agenda.approve!(@user)
    @agenda.publish!(@user)
    @path = dated_agenda_path(@agenda)
  end

  test "email code returns through retries and session rotation to the shared agenda without query tokens" do
    get "#{@path}?token=not-a-destination&return_to=https://evil.example"
    assert_redirected_to new_session_path
    follow_redirect!
    request_email
    post code_session_path, params: { code: "not-a-code" }
    assert_redirected_to code_session_path
    get new_session_path
    code = request_email
    post code_session_path, params: { code: code }
    assert_redirected_to @path
    assert_signed_in_agenda
    assert_nil request.session[SignInReturnPath::SESSION_KEY]
    get @path
    assert_response :success
    assert_select "article.agenda-doc", text: /Synthetic Shared Agenda/
    assert_equal 1, @user.sessions.count
  end

  test "magic link previews do not consume token or lose the requesting browser destination" do
    get @path
    request_email
    email = ActionMailer::Base.deliveries.last.text_part.body.to_s
    token = email[/token=([A-Za-z0-9_-]+)/, 1]
    assert token
    link = @user.magic_links.order(:created_at).last
    2.times do
      get magic_link_session_path(token: token)
      assert_response :success
      head magic_link_session_path(token: token)
      assert_response :success
      assert_nil link.reload.used_at
      assert_equal 0, Session.count
    end
    post magic_link_session_path, params: { token: token }
    assert_redirected_to @path
    assert_signed_in_agenda
    assert link.reload.used_at
    delete session_path
    post magic_link_session_path, params: { token: token }
    assert_redirected_to new_session_path
    assert_equal 0, Session.count
  end

  test "passkey sign-in returns the shared agenda and still verifies the challenge and credential" do
    get @path
    stored = @user.passkey_credentials.create!(external_id: "shared-passkey", public_key: "public-key", sign_count: 1)
    credential = Struct.new(:id, :sign_count, :verified_args) do
      def verify(challenge, **options)
        self.verified_args = [ challenge, options ]
      end
    end.new(stored.external_id, 2)
    post authentication_options_passkeys_path
    assert_response :success
    challenge = response.parsed_body.fetch("challenge")
    with_stubbed_class_method(WebAuthn::Credential, :from_get, ->(*) { credential }) do
      post authentication_passkeys_path, params: { publicKeyCredential: { id: stored.external_id } }, as: :json
    end
    assert_response :success
    assert_equal @path, response.parsed_body.fetch("redirect_url")
    assert_equal [ challenge, { public_key: "public-key", sign_count: 1, user_verification: true } ], credential.verified_args
    assert_equal 2, stored.reload.sign_count
    assert stored.last_used_at
    assert_equal 1, @user.sessions.count
    get response.parsed_body.fetch("redirect_url")
    assert_response :success
    assert_select "article.agenda-doc", text: /Synthetic Shared Agenda/
    get @path
    assert_response :success
  end

  test "destination authorization is checked after sign-in when officer permissions change" do
    target = edit_admin_dated_agenda_path(@agenda)
    get target
    assert_redirected_to new_session_path
    @grant.destroy!
    post magic_link_session_path, params: { token: MagicLink.create_for!(@user).token }
    assert_redirected_to target
    follow_redirect!
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "body", text: /You do not have permission to open that page/
    assert_select "form[action=?]", admin_dated_agenda_path(@agenda), count: 0
    get target
    assert_redirected_to root_path
  end

  test "a formerly published agenda is still hidden after returning from sign-in" do
    get @path
    @agenda.update!(status: "draft")
    post magic_link_session_path, params: { token: MagicLink.create_for!(@user).token }
    assert_redirected_to @path
    follow_redirect!
    assert_response :not_found
    assert_select "article.agenda-doc", count: 0
    get @path
    assert_response :not_found
  end

  test "changed browsers do not inherit the destination and clearing cookies loses it" do
    get @path
    link = MagicLink.create_for!(@user)
    open_session do |other_browser|
      other_browser.post magic_link_session_path, params: { token: link.token }
      other_browser.assert_redirected_to root_path
      other_browser.follow_redirect!
      other_browser.assert_response :success
    end
    assert_nil cookies[:session_id]
    get new_session_path
    assert_response :success
    reset!
    post magic_link_session_path, params: { token: MagicLink.create_for!(@user).token }
    assert_redirected_to root_path
  end

  test "another browser uses its own destination rather than the email requesting browser's" do
    get @path
    link = MagicLink.create_for!(@user)
    open_session do |other_browser|
      other_browser.get meetings_path
      other_browser.assert_redirected_to new_session_path
      other_browser.post magic_link_session_path, params: { token: link.token }
      other_browser.assert_redirected_to meetings_path
      other_browser.follow_redirect!
      other_browser.assert_response :success
    end
  end

  test "expired destinations fall back to dashboard and the latest supported navigation wins" do
    get @path
    travel 16.minutes do
      post magic_link_session_path, params: { token: MagicLink.create_for!(@user).token }
      assert_redirected_to root_path
    end
    delete session_path
    get @path
    get meetings_path
    post magic_link_session_path, params: { token: MagicLink.create_for!(@user).token }
    assert_redirected_to meetings_path
    follow_redirect!
    assert_response :success
  end

  test "POST HEAD JSON file and auth routes are not captured and supplied return URLs are ignored" do
    [ [ :post, registration_options_passkeys_path, {} ], [ :head, @path, {} ],
      [ :get, @path, { as: :json } ], [ :get, print_dated_agenda_path(@agenda), {} ],
      [ :get, new_agent_access_reauthentication_path, {} ] ].each do |method, path, options|
      open_session do |browser|
        browser.public_send(method, path, **options)
        browser.assert_redirected_to new_session_path
        browser.get new_session_path, params: { return_to: "//evil.example" }
        browser.post magic_link_session_path, params: { token: MagicLink.create_for!(@user).token, return_to: @path }
        browser.assert_redirected_to root_path
      end
    end
  end

  private

  def request_email
    perform_enqueued_jobs { post session_path, params: { email_address: @user.email_address } }
    assert_redirected_to code_session_path
    code = ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    assert code
    code
  end

  def assert_signed_in_agenda
    follow_redirect!
    assert_response :success
    assert_select "article.agenda-doc", text: /Synthetic Shared Agenda/
    assert_select ".app-menu-panel", text: /Synthetic Member/
  end
end
