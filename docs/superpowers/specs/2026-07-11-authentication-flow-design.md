# Authentication Flow Design (login / passkey / email)

This spec is the handoff for a session dedicated to finishing the passwordless
authentication flow end-to-end. It documents the verified current state, the gaps, the
intended user journey, the screens to build in the visual system, the technical approach,
open decisions, and a definition of done.

Related: `docs/superpowers/specs/2026-07-11-visual-design-system-design.md` (the visual
system and the readability hard rule — every screen below must follow both) and
`docs/ARCHITECTURE.md` (identity model, passwordless auth, disabled-user rule).

## Goal

A member can sign in with a magic-link email, be guided to add a passkey, and thereafter
sign in with the passkey — with the email link always available as a fallback. Passkeys can
be viewed, named, and removed. Disabled users can never sign in by any method.

## Current State (verified 2026-07-11 by code inspection + passing tests)

### Working

- **Magic-link email sign-in.** `SessionsController#create` looks up the user, and (only for
  an existing, non-disabled user) creates a `MagicLink` and sends `MagicLinksMailer.login`.
  `#magic_link` (GET) shows a confirm page; (POST) consumes the token and starts a session.
  `MagicLink` uses an HMAC-hashed token, a 15-minute TTL, single-use (`used_at`), row locking,
  and a disabled-user check. Sign-in and confirm screens are styled in the Deco `entry`
  layout. Covered by `sessions_controller_test.rb`, `magic_link_test.rb`, `login_page_test.rb`.
- **Passkey backend (complete).** `config/initializers/webauthn.rb` sets origin / rp_id /
  rp_name (dev: localhost). `PasskeysController` implements `registration_options`,
  `registration`, `authentication_options`, `authentication`, `index` (JSON), and `destroy`,
  using the `webauthn` gem and the `PasskeyCredential` model. Disabled users are rejected at
  `authentication`. Covered by `passkeys_controller_test.rb`.
- **Sessions & identity.** `start_new_session_for` / `resume_session` / `terminate_current_session`
  in `ApplicationController`; disabled users are blocked on resume, magic-link consume, and
  passkey auth. Setup wizard creates the first user with all permission grants.

### Missing or stubbed (this slice's work)

1. **No passkey front-end JavaScript.** There is no Stimulus controller calling the browser
   WebAuthn APIs (`navigator.credentials.create` / `.get`). The login "Sign in with a passkey"
   button is an inert placeholder (`button[data-passkey-signin]`, TODO comment). No importmap
   pin for a WebAuthn JSON helper.
2. **No guided passkey registration after first login.** `#magic_link` consume redirects to
   `root`. The roadmap/architecture call for guiding the user to add a passkey after the first
   magic-link login; that screen/step does not exist.
3. **No human-facing passkey management page.** `PasskeysController#index` renders JSON only;
   `#destroy` redirects to `passkeys_path` (also JSON). There is no styled HTML page to view,
   name, or remove passkeys.
4. **Dev email is not viewable, and the job worker is not running in dev.**
   - No `letter_opener`; development `delivery_method` is unset (would attempt SMTP), and
     `raise_delivery_errors=false` swallows failures.
   - `Procfile.dev` runs only `web` and `css` — no `jobs` process — so `deliver_later`
     (Active Job → Solid Queue) is enqueued but never processed in dev. The magic link never
     arrives, which blocks manual/system testing of the flow.
5. **Production email + WebAuthn env not configured.** `MAIL_FROM`, a production
   `delivery_method`/provider, and `WEBAUTHN_ORIGIN` / `WEBAUTHN_RP_ID` / `WEBAUTHN_RP_NAME`
   are `nil` in production until set. The design spec's stated preference is Loops.so behind a
   replaceable service boundary.
6. **CSRF on the JSON endpoints.** The passkey POST endpoints are CSRF-protected
   (`ApplicationController` < `ActionController::Base`, default forgery protection). The
   front-end must send `X-CSRF-Token` from the `csrf_meta_tags` meta tag.
7. **Minimal magic-link email template.** Functional but unbranded; should get a plain,
   readable, big-button template with an expiry note.

## Intended End-to-End Journey

1. **Sign in (magic link)** — [done] enter email → "Check your email."
2. **Email** — a branded, plain magic-link email with a large button and the "works once,
   expires in 15 minutes" note. Must be viewable in dev.
3. **Confirm sign-in** — [done] click link → confirm page → session started.
4. **First-login passkey invitation** — NEW: when a signed-in user has no passkeys (first
   login), invite them to add one ("Make next time easier — add a passkey to this device").
   Plain, reassuring, and skippable ("Not now").
5. **Passkey registration** — the browser WebAuthn create ceremony, launched from the
   invitation and from the management page; on success → dashboard.
6. **Returning sign-in with a passkey** — the login page's passkey button runs the WebAuthn
   get ceremony → session. The email link stays as the fallback.
7. **Passkey management (Security page)** — NEW: list passkeys (nickname, created, last used),
   add another, remove one (with a confirm). Styled in the app shell.
8. **Sign out; disabled-user handling** — [done].

## Screens to Design/Build (in the visual system; obey the readability hard rule)

- **First-login passkey invitation** — entry-style screen or a dashboard card. Plain language,
  large primary "Add a passkey" button, secondary "Not now."
- **Passkey management / Security page** — app shell, a list of passkeys with add/remove,
  remove confirmation. Lives under Settings › Security (or a Security nav item).
- **Magic-link email template** — branded, big button, expiry note, plain fallback URL.
- **Login passkey button, wired** — with progress and graceful error states ("That didn't
  work — try the email link instead"), and feature-detection (hide/disable when the browser
  has no WebAuthn).

## Technical Approach

- **Passkey Stimulus controller** (e.g. `app/javascript/controllers/passkeys_controller.js`):
  - *Register:* `POST /passkeys/registration_options` → `navigator.credentials.create({publicKey})`
    → `POST /passkeys/registration` with the credential JSON (+ optional nickname).
  - *Authenticate:* `POST /passkeys/authentication_options` →
    `navigator.credentials.get({publicKey})` → `POST /passkeys/authentication` → on success,
    `Turbo.visit("/")` (or full redirect).
  - Send `X-CSRF-Token` (from the meta tag) and `Accept: application/json` on every request.
  - Handle base64url ⇄ ArrayBuffer conversion. **Recommended:** pin `@github/webauthn-json`
    via importmap and use its `create`/`get` wrappers (they consume the exact JSON the backend
    already emits via `WebAuthn::Credential.options_for_*`). Alternative: hand-rolled helpers.
  - Feature-detect `window.PublicKeyCredential`; disable the passkey button when absent.
- **Post-login routing:** after `#magic_link` consume, if `current_user.passkey_credentials.empty?`,
  send the user to the passkey invitation instead of `root` (decision below).
- **Passkey management route:** make `PasskeysController#index` respond to HTML (list) as well
  as JSON, or add a small `SecurityController`; give `#destroy` an HTML confirm. Keep the JSON
  responses for the JS ceremonies.
- **Dev email visibility:** add `letter_opener_web` (or `letter_opener`) and set the dev
  `delivery_method`; AND make the email actually send in dev — either add a `jobs:` line to
  `Procfile.dev` (run Solid Queue), or use an inline/async Active Job adapter in development,
  or `deliver_now` in development. Pick one and document it.
- **Production email:** configure the provider (Loops.so preferred) behind a service boundary;
  set `MAIL_FROM` and the `WEBAUTHN_*` env vars. Record these in `docs/DEPLOYMENT.md`.

## Open Decisions (resolve at the start of the next session)

- **WebAuthn JSON helper:** `@github/webauthn-json` (recommended) vs. hand-rolled base64url.
- **Passkey invitation placement:** dedicated full screen on first login (recommended) vs. a
  dismissible dashboard card vs. both (screen first time, card if skipped).
- **Dev email mechanism:** `letter_opener_web` + a dev job process (recommended) vs. mailer
  previews + reading the token from the record.
- **Where passkey management lives:** Settings › Security tab vs. a standalone Security page.
- **Production provider:** Loops.so vs. SMTP — validate transactional deliverability first.

## Definition of Done

- A new user can, in the running app: receive and click a magic link (**visible in dev**),
  land signed in, be invited to add a passkey, complete the WebAuthn **registration**, sign
  out, and sign back in with the **passkey** — with the email link working as a fallback.
- Passkeys can be listed, named, and removed from a styled Security page (remove confirmed).
- WebAuthn is feature-detected; cancels/failures degrade gracefully to the email link.
- Disabled users cannot sign in by any method (already enforced — keep covered by tests).
- Dev email is viewable and actually delivered; production email + `WEBAUTHN_*` env vars are
  documented in `docs/DEPLOYMENT.md`.
- All new screens obey the design system and the readability hard rule.

## Testing Notes

- Controller-level coverage for the passkey endpoints already exists; keep/extend it.
- The **browser** WebAuthn ceremonies are hard to unit-test (they need a virtual authenticator,
  e.g. Chrome DevTools Protocol's virtual authenticator in a system test). Treat a scripted
  virtual-authenticator system test as a stretch goal; at minimum, verify the ceremonies
  manually in a real browser and keep the JSON endpoints covered.
- The **magic-link happy path** is a good candidate for a full system test once dev email is
  visible.
```
