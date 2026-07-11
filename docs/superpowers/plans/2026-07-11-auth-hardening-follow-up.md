# Auth Hardening Follow-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the immediate authentication and setup surface without building the full session/device management system yet.

**Architecture:** Use Rails controller-level protections and small model/controller helpers. Keep user-facing responses generic for auth throttling, keep setup recovery conservative, and record session activity through the existing `sessions.last_seen_at` column.

**Tech Stack:** Rails 8.1, Minitest integration tests, Rails built-in `rate_limit`, signed cookies, PostgreSQL-backed Active Record models.

**Repository note:** Do not commit during execution unless the human explicitly requests it.

---

## File Structure

- Modify `app/controllers/application_controller.rb`
  - Add 180-day inactivity handling and periodic `last_seen_at` touch in `resume_session`.
  - Add a small helper to clear invalid/stale sessions consistently.
- Modify `app/controllers/sessions_controller.rb`
  - Add Rails `rate_limit` rules for magic-link request and magic-link token consumption.
  - Add a generic throttled response handler.
- Modify `app/controllers/passkeys_controller.rb`
  - Add Rails `rate_limit` rules for public passkey authentication endpoints.
  - Add a generic throttled JSON response handler.
- Modify `app/controllers/setup_controller.rb`
  - Block unauthenticated setup reopening when both organization and user data already exist.
- Modify `public/406-unsupported-browser.html`
  - Replace the generic message with officer-facing upgrade guidance.
- Modify `test/controllers/sessions_controller_test.rb`
  - Cover throttling and stale-session expiration/touch behavior.
- Modify `test/controllers/passkeys_controller_test.rb`
  - Cover throttling for public passkey authentication endpoints.
- Modify `test/controllers/setup_controller_test.rb`
  - Cover setup guard when app data exists but setup flag is missing.
- Add `test/system` is not needed for this pass.

---

## Task 1: Session activity and 180-day inactive expiration

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Test: `test/controllers/dashboard_controller_test.rb`

- [ ] **Step 1: Add failing tests for stale-session expiration and active-session touch**

Add these tests to `test/controllers/dashboard_controller_test.rb`:

```ruby
test "stale sessions older than 180 days are expired" do
  Installation.singleton.update!(setup_completed_at: Time.current)
  user = users(:one)
  stale_session = Session.create!(
    user: user,
    ip_address: "127.0.0.1",
    user_agent: "test",
    last_seen_at: 181.days.ago
  )

  cookies.signed[:session_id] = stale_session.id

  get dashboard_path

  assert_redirected_to new_session_path
  assert_nil Session.find_by(id: stale_session.id)
end

test "resumed sessions update last seen periodically" do
  Installation.singleton.update!(setup_completed_at: Time.current)
  user = users(:one)
  active_session = Session.create!(
    user: user,
    ip_address: "127.0.0.1",
    user_agent: "test",
    last_seen_at: 2.hours.ago
  )

  cookies.signed[:session_id] = active_session.id

  get dashboard_path

  active_session.reload

  assert_response :success
  assert active_session.last_seen_at > 10.minutes.ago
end
```

- [ ] **Step 2: Run the targeted tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/dashboard_controller_test.rb
```

Expected: both new tests fail because stale sessions are not expired and `last_seen_at` is not touched.

- [ ] **Step 3: Implement inactive expiration and periodic touch**

Update `app/controllers/application_controller.rb` so the class includes these constants and helper methods:

```ruby
class ApplicationController < ActionController::Base
  SESSION_INACTIVITY_LIMIT = 180.days
  SESSION_TOUCH_INTERVAL = 15.minutes

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # existing code...

  def resume_session
    return if Current.session.present?

    session_id = cookies.signed[:session_id]
    return if session_id.blank?

    session = Session.find_by(id: session_id)
    return clear_session_cookie if session.blank?

    if session.user.disabled_at.present? || session_inactive_too_long?(session)
      session.destroy!
      clear_session_cookie
      return
    end

    touch_session_if_needed(session)
    Current.session = session
  end

  private

  def session_inactive_too_long?(session)
    session.last_seen_at.present? && session.last_seen_at < SESSION_INACTIVITY_LIMIT.ago
  end

  def touch_session_if_needed(session)
    return if session.last_seen_at.present? && session.last_seen_at > SESSION_TOUCH_INTERVAL.ago

    session.update_columns(last_seen_at: Time.current, updated_at: Time.current)
  end

  def clear_session_cookie
    cookies.delete(:session_id)
    Current.session = nil
  end
end
```

Keep the existing public methods intact. If `private` placement would make `setup_complete?` unavailable to controllers, place the new helper methods after all public controller methods and keep `setup_complete?` public/protected as it is today.

- [ ] **Step 4: Run the targeted tests and verify they pass**

Run:

```bash
bin/rails test test/controllers/dashboard_controller_test.rb
```

Expected: 0 failures.

- [ ] **Step 5: Checkpoint**

Review:

```bash
git diff -- app/controllers/application_controller.rb test/controllers/dashboard_controller_test.rb
```

Do not commit unless explicitly instructed.

---

## Task 2: Public magic-link throttling

**Files:**
- Modify: `app/controllers/sessions_controller.rb`
- Test: `test/controllers/sessions_controller_test.rb`

- [ ] **Step 1: Add failing tests for magic-link throttling**

Add these tests to `test/controllers/sessions_controller_test.rb`:

```ruby
test "magic link requests are rate limited by requester" do
  Installation.singleton.update!(setup_completed_at: Time.current)

  10.times do
    post session_path, params: { email_address: users(:one).email_address }
  end

  post session_path, params: { email_address: users(:one).email_address }

  assert_redirected_to new_session_path
  assert_equal "Please wait a few minutes and try again.", flash[:alert]
end

test "magic link consumption is rate limited by requester" do
  Installation.singleton.update!(setup_completed_at: Time.current)

  10.times do
    post magic_link_session_path, params: { token: "invalid-token" }
  end

  post magic_link_session_path, params: { token: "invalid-token" }

  assert_redirected_to new_session_path
  assert_equal "Please wait a few minutes and try again.", flash[:alert]
end
```

- [ ] **Step 2: Run targeted tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/sessions_controller_test.rb
```

Expected: the new throttling tests fail because no rate limits exist yet.

- [ ] **Step 3: Add Rails rate limits and generic throttled response**

Update the top of `app/controllers/sessions_controller.rb`:

```ruby
class SessionsController < ApplicationController
  layout "entry", only: %i[new create magic_link]
  skip_before_action :redirect_to_setup_if_needed, only: %i[new create magic_link]

  rate_limit to: 10,
    within: 5.minutes,
    only: :create,
    name: "magic_link_requests",
    by: -> { request.remote_ip },
    with: :redirect_after_auth_throttle

  rate_limit to: 10,
    within: 5.minutes,
    only: :magic_link,
    name: "magic_link_consumption",
    by: -> { request.remote_ip },
    with: :redirect_after_auth_throttle

  # existing actions...

  private

  def redirect_after_auth_throttle
    redirect_to new_session_path, alert: "Please wait a few minutes and try again."
  end
end
```

If a GET request to `magic_link` is unexpectedly throttled by this configuration, change the `magic_link` rate limit to use `if: -> { request.post? }` if supported, or add a separate POST-only route/controller action in the smallest Rails-conventional way.

- [ ] **Step 4: Run targeted tests and verify they pass**

Run:

```bash
bin/rails test test/controllers/sessions_controller_test.rb
```

Expected: 0 failures.

- [ ] **Step 5: Checkpoint**

Review:

```bash
git diff -- app/controllers/sessions_controller.rb test/controllers/sessions_controller_test.rb
```

Do not commit unless explicitly instructed.

---

## Task 3: Public passkey authentication throttling

**Files:**
- Modify: `app/controllers/passkeys_controller.rb`
- Test: `test/controllers/passkeys_controller_test.rb`

- [ ] **Step 1: Add failing tests for passkey auth endpoint throttling**

Add these tests to `test/controllers/passkeys_controller_test.rb`:

```ruby
test "passkey authentication options are rate limited by requester" do
  Installation.singleton.update!(setup_completed_at: Time.current)

  20.times do
    post authentication_options_passkeys_path
  end

  post authentication_options_passkeys_path

  assert_response :too_many_requests
  assert_equal({ "error" => "Please wait a few minutes and try again." }, JSON.parse(response.body))
end

test "passkey authentication submissions are rate limited by requester" do
  Installation.singleton.update!(setup_completed_at: Time.current)

  invalid_credential = {
    publicKeyCredential: {
      id: "invalid",
      rawId: "invalid",
      type: "public-key",
      response: {
        authenticatorData: "invalid",
        clientDataJSON: "invalid",
        signature: "invalid",
        userHandle: "invalid"
      },
      clientExtensionResults: {}
    }
  }

  20.times do
    post authentication_passkeys_path, params: invalid_credential
  end

  post authentication_passkeys_path, params: invalid_credential

  assert_response :too_many_requests
  assert_equal({ "error" => "Please wait a few minutes and try again." }, JSON.parse(response.body))
end
```

- [ ] **Step 2: Run targeted tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/passkeys_controller_test.rb
```

Expected: the new throttling tests fail because no rate limits exist yet.

- [ ] **Step 3: Add Rails rate limits and JSON throttled response**

Update the top of `app/controllers/passkeys_controller.rb`:

```ruby
class PasskeysController < ApplicationController
  skip_before_action :redirect_to_setup_if_needed
  before_action :require_authentication, except: %i[authentication_options authentication]

  rate_limit to: 20,
    within: 5.minutes,
    only: :authentication_options,
    name: "passkey_authentication_options",
    by: -> { request.remote_ip },
    with: :render_auth_throttle

  rate_limit to: 20,
    within: 5.minutes,
    only: :authentication,
    name: "passkey_authentication",
    by: -> { request.remote_ip },
    with: :render_auth_throttle

  # existing actions...

  private

  def render_auth_throttle
    render json: { error: "Please wait a few minutes and try again." }, status: :too_many_requests
  end

  def public_key_credential_params
    # existing method body
  end
end
```

Keep the existing `public_key_credential_params` private method; do not duplicate it.

- [ ] **Step 4: Run targeted tests and verify they pass**

Run:

```bash
bin/rails test test/controllers/passkeys_controller_test.rb
```

Expected: 0 failures.

- [ ] **Step 5: Checkpoint**

Review:

```bash
git diff -- app/controllers/passkeys_controller.rb test/controllers/passkeys_controller_test.rb
```

Do not commit unless explicitly instructed.

---

## Task 4: Bootstrap setup recovery guard

**Files:**
- Modify: `app/controllers/setup_controller.rb`
- Test: `test/controllers/setup_controller_test.rb`

- [ ] **Step 1: Add failing tests for existing-data setup lockout**

Add these tests to `test/controllers/setup_controller_test.rb`:

```ruby
test "setup does not reopen when organization and user exist but completion flag is missing" do
  person = Person.create!(first_name: "Jane", last_name: "Doe")
  User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
  Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
  Installation.singleton.update!(setup_completed_at: nil)

  get new_setup_path

  assert_redirected_to new_session_path
  assert_equal "Setup recovery requires operator help.", flash[:alert]
end

test "setup post does not grant admin when organization and user exist but completion flag is missing" do
  person = Person.create!(first_name: "Jane", last_name: "Doe")
  User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
  Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
  Installation.singleton.update!(setup_completed_at: nil)

  assert_no_difference -> { PermissionGrant.count } do
    post setup_path, params: {
      organization: {
        name: "Another Post",
        unit_number: "166",
        timezone: "America/Chicago",
        default_location_name: "Club",
        default_location_address: "123 Main St"
      },
      person: {
        first_name: "Andre",
        last_name: "Robitaille",
        email_address: "andre@example.com"
      }
    }
  end

  assert_redirected_to new_session_path
  assert_equal "Setup recovery requires operator help.", flash[:alert]
end
```

- [ ] **Step 2: Run targeted tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/setup_controller_test.rb
```

Expected: the two new tests fail because setup currently reopens based only on `setup_completed_at`.

- [ ] **Step 3: Implement the recovery guard**

Update `app/controllers/setup_controller.rb`:

```ruby
class SetupController < ApplicationController
  skip_before_action :redirect_to_setup_if_needed
  before_action :redirect_if_already_configured
  before_action :redirect_if_operator_recovery_required

  SETUP_ADVISORY_LOCK_KEY = 7_106_206

  # existing actions...

  private

  def redirect_if_already_configured
    return unless setup_complete?

    redirect_to root_path
  end

  def redirect_if_operator_recovery_required
    return unless Organization.exists? && User.exists?
    return if setup_complete?

    redirect_to new_session_path, alert: "Setup recovery requires operator help."
  end

  # existing private methods...
end
```

This preserves existing partial-repair tests where only an organization or only a user exists.

- [ ] **Step 4: Run targeted tests and verify they pass**

Run:

```bash
bin/rails test test/controllers/setup_controller_test.rb
```

Expected: 0 failures, including the existing partial setup repair tests.

- [ ] **Step 5: Checkpoint**

Review:

```bash
git diff -- app/controllers/setup_controller.rb test/controllers/setup_controller_test.rb
```

Do not commit unless explicitly instructed.

---

## Task 5: Better unsupported-browser page

**Files:**
- Modify: `public/406-unsupported-browser.html`
- Test: manual/static file inspection

- [ ] **Step 1: Replace the message block**

In `public/406-unsupported-browser.html`, replace the current article paragraph:

```html
<p><strong>Your browser is not supported.</strong><br> Please upgrade your browser to continue.</p>
```

with:

```html
<p><strong>This browser is too old for LegionPostTools.</strong></p>
<p>LegionPostTools needs a current browser so officers can sign in safely and use the app reliably.</p>
<p>Please update Chrome, Edge, Firefox, or Safari, then try again. If you need help, contact your post app administrator.</p>
```

- [ ] **Step 2: Inspect the static page content**

Run:

```bash
ruby -e 'html = File.read("public/406-unsupported-browser.html"); abort "missing copy" unless html.include?("This browser is too old for LegionPostTools") && html.include?("contact your post app administrator"); puts "unsupported browser page copy present"'
```

Expected output:

```text
unsupported browser page copy present
```

- [ ] **Step 3: Checkpoint**

Review:

```bash
git diff -- public/406-unsupported-browser.html
```

Do not commit unless explicitly instructed.

---

## Task 6: Full verification

**Files:**
- All files modified above.

- [ ] **Step 1: Run targeted tests**

Run:

```bash
bin/rails test test/controllers/dashboard_controller_test.rb test/controllers/sessions_controller_test.rb test/controllers/passkeys_controller_test.rb test/controllers/setup_controller_test.rb
```

Expected: 0 failures.

- [ ] **Step 2: Run full Rails test suite**

Run:

```bash
bin/rails test
```

Expected: 0 failures.

- [ ] **Step 3: Run security/static checks**

Run:

```bash
bin/brakeman
bin/rubocop
bin/bundler-audit
```

Expected: Brakeman reports 0 warnings, RuboCop reports 0 offenses, bundler-audit reports no vulnerabilities.

- [ ] **Step 4: Review final diff**

Run:

```bash
git diff --stat
git diff -- app/controllers/application_controller.rb app/controllers/sessions_controller.rb app/controllers/passkeys_controller.rb app/controllers/setup_controller.rb public/406-unsupported-browser.html test/controllers/dashboard_controller_test.rb test/controllers/sessions_controller_test.rb test/controllers/passkeys_controller_test.rb test/controllers/setup_controller_test.rb docs/ROADMAP.md docs/superpowers/specs/2026-07-11-auth-hardening-follow-up-design.md docs/superpowers/plans/2026-07-11-auth-hardening-follow-up.md
```

Expected: only intended auth hardening, setup guard, browser page, roadmap/spec/plan changes are present.

---

## Self-Review Notes

- Spec coverage: unsupported browser page, public auth throttling, bootstrap recovery guard, 180-day inactive session rule, roadmap/GitHub tracking are covered.
- Placeholder scan: no TBD/TODO placeholders remain.
- Type/signature consistency: all referenced controller paths and route helpers match the existing routes.
