# Authentication Flow Design (login / passkey / email)

This spec is the handoff for a session dedicated to finishing the passwordless
authentication flow end-to-end. It documents the verified current state, the gaps, the
intended user journey, the screens to build in the visual system, the technical approach,
open decisions, and a definition of done.

Related: `docs/superpowers/specs/2026-07-11-visual-design-system-design.md` (the visual
system and the readability hard rule — every screen below must follow both) and
`docs/ARCHITECTURE.md` (identity model, passwordless auth, disabled-user rule).

## Implementation Status — COMPLETE (2026-07-11)

The full flow below was built, tested, and verified end-to-end in a real browser (magic-link
sign-in → first-login passkey invitation → passkey registration → sign out → sign in with the
passkey → rename/remove on Settings › Security). All items in the Definition of Done are met.
Notable specifics from implementation:

- **Passkey user handle bug (fixed).** `registration_options` originally sent the sequential
  DB id as the WebAuthn `user.id`, which is not valid base64url, so the browser `create()`
  ceremony threw before prompting. Users now carry a stable opaque base64url **`webauthn_id`**
  (migration `20260711171917`; generated on create) used as the handle, per the gem/spec.
- **Resolved decisions** were implemented as recorded below (dashboard card, `letter_opener_web`,
  Settings › Security, `@github/webauthn-json` vendored, Loops.so behind a `MailDelivery` seam).
- **Passkey rename** was added (`PATCH /passkeys/:id`) with an edit-in-place control on the
  Security page; flash confirmations render in the app shell.
- **Dev/testing caveat:** passkeys need a **secure context** — they are disabled over
  `http://<LAN-IP>` (feature-detection working as designed). Test via `localhost` (e.g. an SSH
  tunnel to the app host) or HTTPS; production is HTTPS. A scripted virtual-authenticator system
  test was attempted but deferred due to headless-Chrome friction; the JSON endpoints stay
  covered by `passkeys_controller_test.rb` and the ceremonies are verified manually.

The remaining sections document the design as built.

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

- **First-login passkey invitation** — a **dismissible dashboard card** (resolved). Plain
  language, large primary "Add a passkey" button, quiet "×" dismiss. Shown while the user has no
  passkeys; dismiss is session-scoped.
- **Passkey management / Security page** — app shell, **Settings › Security tab** (resolved): a
  list of passkeys with add/remove and a remove confirmation.
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
  - Handle base64url ⇄ ArrayBuffer conversion via **`@github/webauthn-json`** (resolved),
    vendored locally through importmap; use its `create`/`get` wrappers (they consume the exact
    JSON the backend already emits via `WebAuthn::Credential.options_for_*`).
  - Feature-detect `window.PublicKeyCredential`; disable the passkey button when absent.
- **Post-login routing:** unchanged — after `#magic_link` consume the user still lands on `root`.
  The passkey invitation is a **dashboard card** rendered when `current_user.passkey_credentials.empty?`
  (resolved), not a routing redirect.
- **Passkey management route:** `PasskeysController#index` gains an **HTML** response that renders
  the **Settings › Security** tab body (list of passkeys), keeping the JSON response for the JS
  ceremonies; `#destroy` gets an HTML confirm. A minimal `SettingsController`/Settings shell hosts
  the Security tab.
- **Dev email visibility:** add **`letter_opener_web`** and set the dev `delivery_method` to
  `:letter_opener_web`, mounting its inbox at `/letter_opener` (resolved). No `Procfile.dev`
  change is needed: dev's unset `queue_adapter` means Active Job runs `:async` in-process, so
  `deliver_later` already delivers. (Verify the adapter empirically during the build.)
- **Production email:** wire **Loops.so** behind a **replaceable delivery service boundary**
  (resolved) so the provider is swappable without touching mailer callers; set `MAIL_FROM` and
  the `WEBAUTHN_*` env vars. Record all of it in `docs/DEPLOYMENT.md`. Deliverability is validated
  by the operator on the real host.

## Resolved Decisions (2026-07-11)

These were the open decisions; resolved at the start of the implementation session.

- **WebAuthn JSON helper:** **`@github/webauthn-json`**, pinned via importmap and **vendored
  locally** (`bin/importmap pin @github/webauthn-json --download`) so there is no runtime CDN
  dependency. Its `create()` / `get()` consume exactly the JSON the backend already emits via
  `WebAuthn::Credential.options_for_*` and handle all base64url ⇄ ArrayBuffer conversion.
- **Passkey invitation placement:** a **dismissible dashboard card** (no dedicated full-screen
  step). After the magic-link consume the user lands on `root` (dashboard) as today. The card
  shows whenever `current_user.passkey_credentials.empty?`. Its "×" dismiss is **session-scoped**:
  it reappears on the next login until the user actually adds a passkey, gently re-nudging
  adoption without a persisted "never show again." This adds **one** well-formed card to the
  existing dashboard placeholder — it is **not** the deferred full dashboard redesign.
- **Dev email mechanism:** **`letter_opener_web`**. Development's `queue_adapter` is unset, so it
  uses Rails' default **`:async`** adapter — `deliver_later` already runs in-process in dev, so
  **no `jobs:` line in `Procfile.dev` is required**. The real dev blocker was that
  `delivery_method` was unset (defaulting to `:smtp`) while `raise_delivery_errors=false`
  swallowed the failure. Fix: set the dev `delivery_method` to `:letter_opener_web` and mount its
  inbox at `/letter_opener`, reachable off-box at `http://192.168.37.41:3000/letter_opener`.
- **Where passkey management lives:** **Settings › Security tab.** Build a minimal Settings shell
  now (page bar + tab strip) with **Security** as its only tab (Organization/People tabs later).
  `PasskeysController#index` gains an HTML response (the Security tab body); JSON stays for the JS
  ceremonies. `#destroy` gets an HTML confirm.
- **Production provider:** **Loops.so**, wired behind a **replaceable delivery service boundary**
  so the provider can be swapped without touching mailer callers. Set `MAIL_FROM` and the
  `WEBAUTHN_*` env vars; document all of it in `docs/DEPLOYMENT.md`. Transactional deliverability
  is validated by the operator on the real host (out of scope for this session's automated tests).

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
