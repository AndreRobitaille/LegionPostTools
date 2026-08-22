# Agent Sign-in and Access Implementation Plan

## Selected design and constraints

**Goal:** Make Grok Agent Computer sign-in work when email is received on another
device, then give the signed-in officer a named, revocable bearer token for reliable
agent API work.

**Design:** Follow
`docs/superpowers/specs/2026-08-22-agent-sign-in-and-access-design.md` and preserve
the authority model in
`docs/superpowers/specs/2026-08-22-officer-agent-operability-design.md`.

**Product constraints:** This remains American Legion post software. Keep the flow
plain for older or low-confidence computer users. The Bot receives the officer's
current app grants; it does not become a generic integration account. Accepted
official minutes remain immutable, and no long-lived credential proves human intent
for an identity-bound act.

**Technical constraints:** Stay in Rails, PostgreSQL, Hotwire/importmap, and the
existing mail-delivery boundary. Do not add a service, OAuth provider, MCP server,
password, or JavaScript-only sign-in requirement.

## Source revision and drift check

At the beginning of implementation:

1. Read `AGENTS.md`, this plan, and both linked design specs.
2. Record `git status --short`, current branch, and `git log -5 --oneline`.
3. Preserve unrelated user changes. If authentication, API base-controller, Profile,
   or mail-delivery code has drifted materially from this plan, update the design
   before coding.
4. Run the focused existing authentication and API tests to establish a baseline.

## Affected components

Expected files and areas include:

- `app/models/magic_link.rb` and its migration/schema.
- `app/controllers/sessions_controller.rb`, session routes, entry views, and login
  integration/system tests.
- `MailDelivery`, both backends, `MagicLinksMailer`, local email templates, and the
  published Loops transactional template.
- A new `AgentAccessToken` model/service, Profile routes/controllers/views, and an
  admin revocation view.
- `Current`, `ApplicationController`, and `Api::BaseController` authentication
  context.
- The generated `AgentHandbook` and `docs/agent-operator-skill.md`.
- A new idempotency/execution record and the API mutation boundary.

Use conventional names discovered from the current source rather than forcing these
suggestions if Rails already provides a clearer local pattern.

## Ordered work packages

### 1. Lock down the cross-device challenge contract with tests

Add failing model and request tests before implementation for:

- eight-digit code generation and normalization of `1234 5678` / `1234-5678`;
- successful consumption with the matching browser challenge;
- rejection from a different or missing browser challenge;
- link and code mutually consuming the same row;
- expiry, replay, disabled user, and five-attempt exhaustion;
- atomic behavior under two consumption attempts;
- indistinguishable browser response and pending-cookie shape for known, unknown,
  and disabled email addresses;
- existing magic-link GET confirmation and POST consumption remaining intact.

Do not expose raw code or browser challenge values through ordinary model inspection,
logs, or persisted attributes.

### 2. Extend `MagicLink` into the shared link-or-code challenge

Add digests and attempt tracking through a migration. Generate independent URL token,
numeric code, and browser selector values with `SecureRandom`. Store keyed HMAC digests
using the existing application-secret pattern, and compare user-supplied values with
`ActiveSupport::SecurityUtils.secure_compare`.

Implement a locked `consume_code!` path that checks used state, expiry, attempt count,
and user disablement in one transaction. Increment failures atomically and make the
fifth failure terminal. Keep `consume!` for links, but have both paths use one internal
consumption routine so email verification, `used_at`, and disabled-user behavior cannot
drift.

Persist a challenge purpose with a safe default for existing rows. Sign-in challenges
may create a normal session. Reauthentication challenges are bound to the current
session and exact `create_agent_access_token` purpose; consuming one may only refresh
that session's authentication timestamp. Reject any attempt to use one purpose at the
other endpoint.

### 3. Add the pending-browser flow and plain code-entry screen

On every email request, place an encrypted, HTTP-only, SameSite, 15-minute pending
selector cookie and redirect to a dedicated code-entry route. For nonexistent or
disabled accounts, issue an indistinguishable random selector without a database row.

The code screen must:

- reuse the current Legion entry layout and existing palette/type system;
- use one large text field labeled “8-digit sign-in code” with `inputmode="numeric"`,
  `autocomplete="one-time-code"`, and a visible `1234 5678` example;
- work with paste, keyboard, screen reader, enlarged text, and no JavaScript;
- provide “Check another email” / resend guidance without exposing account existence;
- remove the pending cookie after success and establish the ordinary `Session`.

Use separate rate-limit buckets for requesting email and submitting codes. Key code
attempt throttling by requester plus a digest or safe fingerprint of the pending
selector, without putting the raw selector or code in logs.

### 4. Carry the code through both mail backends

Change the delivery interface and all callers to accept `login_code:`. Put the code
prominently in the Action Mailer HTML and text versions while retaining the button and
plain-URL fallback. Update service and mailer tests so missing code propagation fails.

Prepare and publish the matching Loops template change. Validate a safe test delivery
before production deployment. Coordinate deployment so the app and published template
agree on the new `login_code` data variable; preserve the current magic-link behavior
if the provider change must roll back.

### 5. Add recent-authentication state

Record when a `Session` last completed primary authentication or explicit
reauthentication. Token creation requires a timestamp no older than ten minutes.

Provide a guided reauthentication path using an existing passkey when available and
the new emailed-code challenge as fallback. Bind the return destination to an
allowlisted Profile token-creation path; never accept an arbitrary return URL. A
successful reauthentication updates the current session rather than creating an
unrelated second session.

Tests must cover stale-session refusal, both reauthentication methods, disabled users,
safe return routing, and inability for an agent bearer token to reauthenticate itself.

### 6. Build the personal `AgentAccessToken` lifecycle

Create a model with owner, public lookup id, keyed secret digest, safe display hint,
name, expiry, last-used time, and revocation time. Issue a 256-bit secret in a
recognizable `lpt_...` format and return the complete value only from the creation
operation. Use indexed public-id lookup followed by constant-time secret comparison.

The active predicate must reject expired or revoked tokens and tokens belonging to a
disabled user. Re-evaluate the user's capabilities on every request. Throttle
`last_used_at` writes to a reasonable interval such as 15 minutes.

Model tests must cover format, one-time issuance, digest-only persistence, expiry,
revocation, disabled users, malformed values, constant behavior for unknown public ids,
and concurrent revocation/use as far as deterministic tests allow.

### 7. Add Profile creation and administrative revocation

Add **Agent access** beneath the existing Profile sign-in section. Reuse the passkey
row vocabulary rather than introducing a new dashboard style.

Self-service behavior:

- list only the signed-in user's tokens with name, hint, created date, expiry, last
  use, and status;
- create only after recent authentication, with a required name and 30/90/180-day
  choice defaulting to 90;
- render the complete token exactly once with Copy and manual-selection fallbacks;
- warn that credentials placed on Grok's shared computer may be available to all Bots
  on that computer;
- revoke with an explicit confirmation and no ability to restore the token.

Add an admin oversight list gated by `manage_settings` that can revoke any token for
incident response but cannot create one for another user or reveal its secret. Log the
administrator who revoked another user's token.

Critique and browser-test creation, one-time reveal, empty/list/revoked states, and
confirmation at desktop and narrow widths. Verify keyboard focus, live Copy status,
manual copy without JavaScript, and readable body/label sizes.

### 8. Authenticate API bearer requests without ambiguity

Teach `Api::BaseController` to authenticate either the existing session or a bearer
token. If an `Authorization: Bearer` header is present, do not fall back to a cookie.
Invalid bearer credentials return the existing `401` JSON shape.

Set explicit current request context for the accountable user and optional agent token.
Run all existing `can?` checks unchanged after authentication. Skip CSRF verification
only for requests that selected bearer authentication; preserve CSRF for session-based
writes. Add `Cache-Control: no-store` to responses that reveal or process credentials
where appropriate, and ensure authorization headers and token values are filtered from
application logs and exception reporting.

Request tests must cover session-only, bearer-only, invalid-bearer-plus-valid-cookie,
revoked/expired/disabled bearer credentials, permission changes after issuance, CSRF
requirements for each mode, and identical resource scoping between modes.

### 9. Require replay protection for machine mutations

Add an idempotency/execution record keyed by agent token plus `Idempotency-Key`. Store
method, normalized path, request fingerprint, processing/completed state, response
status/body, and timestamps. Do not include Authorization, CSRF values, or other secrets
in the fingerprint or stored response metadata.

For bearer-authenticated mutation requests:

- missing keys return `422`;
- the first request owns the key and performs the action once;
- an exact retry returns the original status and JSON;
- reuse with different input returns `409`;
- concurrent first requests serialize rather than duplicate the mutation;
- stale processing records fail safely and are observable;
- completed records are retained for 30 days, then cleaned by a scheduled job.

Session-authenticated human writes remain compatible and do not require an idempotency
key. Add request tests around every current API mutation category, including duplicate
agenda creation and tracked-item updates.

### 10. Adapt the handbook and Grok standing instructions

Make `/api` describe the credential actually used. Session callers get CSRF guidance;
bearer callers get `Authorization` and idempotency examples without a CSRF token.

Update `docs/agent-operator-skill.md` with two explicit paths:

1. For browser sign-in, open Agent Computer, navigate in its browser address bar to
   `/session/new`, ask the human to take over, and enter the emailed code there. Do not
   use `/plugins` for website sign-in.
2. For routine API work, use the named token from Agent Computer's terminal without
   pasting the token into chat, URLs, command history, or logs. Read `/api` first.

Keep the standing note short; detailed endpoint rules stay generated by the app.

### 11. Verify security, accessibility, and compatibility

Run at minimum:

```bash
bin/rails test
bin/rails test:system
bin/rubocop --cache false
bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit check
git diff --check
```

Also perform focused browser QA at desktop and approximately 390px width for email
request, code entry, invalid/expired recovery, recent-authentication prompt, token
creation, one-time copy, list, and revocation.

Challenge the implementation with explicit negative tests: code from another browser,
five guesses, two concurrent consumers, mixed bearer/cookie credentials, revoked token,
permission removal, duplicate idempotent writes, altered-body key reuse, and token text
search across logs and rendered follow-up pages.

## Compatibility and migration

- Existing unused magic links remain usable after migration; new code columns must be
  nullable or backfilled safely so deployment does not invalidate outstanding links.
- The original link button and confirmation POST remain supported.
- Existing session-authenticated API clients continue using CSRF as before.
- Bearer authentication is additive; do not remove browser access or require a token.
- Do not enable token-authenticated unattended mutation until idempotency is deployed.
- Update and validate the Loops template as an explicit deployment dependency.

## Performance and resource checks

No separate service or cache is justified. Verify that bearer lookup uses the unique
public-id index and that code lookup uses an indexed challenge digest. Confirm the
tracked-item and agenda API query counts do not grow with token authentication.

Measure representative authenticated GET latency before and after bearer support in the
same local environment. The design should add one indexed credential lookup, not an
unbounded scan or network hop. Record the observed result; do not invent a target if the
project has no established latency budget.

## Rollout and rollback

1. Deploy additive schema and application changes with link compatibility preserved.
2. Publish and verify the Loops code variable/template.
3. Test cross-device code sign-in on Grok Agent Computer.
4. Create a short-lived named token from the officer's Profile and verify bearer
   `GET /api`.
5. Exercise one idempotent draft operation only with the user's explicit approval.
6. Revoke the test token and prove the next request returns `401`.
7. Create the operational token only after those checks pass.

Rollback disables bearer authentication and token creation first while retaining the
tables for forensic/recovery purposes. The existing link and session paths remain the
fallback. Do not drop credential or idempotency tables during an urgent rollback.

## Acceptance criteria

- Cross-device emailed code sign-in succeeds on the requesting browser and nowhere else.
- Existing magic links still work and link/code cannot both be consumed.
- Enumeration resistance, expiry, attempt limits, and disabled-user checks are tested.
- A recently authenticated user can issue, copy once, list, and revoke only their own
  token; an admin can revoke but not mint or reveal another user's token.
- Valid bearer requests receive exactly the user's current permissions, while invalid,
  expired, revoked, or disabled credentials receive `401` without cookie fallback.
- Session CSRF behavior remains intact; bearer authentication does not expose a CSRF
  token unnecessarily.
- Token-authenticated writes are idempotent and auditable.
- The handbook and short Grok instructions accurately cover both authentication paths.
- Desktop/narrow browser QA and all project verification commands pass.
- Production verification proves sign-in, read-only bearer access, revocation, and
  cleanup without leaving a test credential active.

## Open operational decisions

- Confirm the exact Loops template editing/publishing sequence before deployment.
- Confirm where Grok Agent Computer can store the bearer token without placing it in
  conversation text or shell history. Grok's shared computer is not a per-Bot security
  boundary, and the UI/instructions must say so plainly.
