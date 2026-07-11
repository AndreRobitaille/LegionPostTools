# Auth Hardening Follow-up Design

## Context

LegionPostTools now has passwordless sign-in through magic links and passkeys. The first pass is working, but a code/security review identified several practical hardening items to address before production use by American Legion post officers.

This design intentionally excludes Content Security Policy enforcement and production Loops.so delivery hardening. CSP can wait until the UI is less fluid, and Loops backend reliability will be handled separately.

## Goals

- Keep officer sign-in convenient while reducing obvious abuse paths.
- Improve the unsupported-browser page so officers know what to do.
- Prevent unauthenticated bootstrap recovery from granting admin access over an existing installation.
- Start recording session activity without building the full session/device management system yet.
- Document the full session/device system as a later roadmap item and GitHub issue.

## Non-goals

- No hard daily or weekly session timeout.
- No full device/session management UI in this pass.
- No CSP enforcement in this pass.
- No Loops.so backend reliability changes in this pass.
- No multi-tenant or SaaS-oriented account security model.

## Immediate Changes

### Unsupported browser page

Replace the generic Rails 406 page message with plain LegionPostTools-specific guidance.

The page should say that the browser is too old for LegionPostTools, explain that officers need a current browser, and recommend current Chrome, Edge, Firefox, or Safari. The language should be calm and operational, not technical. It should tell officers to contact their post app administrator if they need help updating.

### Public auth throttling

Add throttling to public authentication endpoints:

- Magic-link email request.
- Magic-link token confirmation/consumption.
- Passkey authentication options.
- Passkey authentication submission.

Responses must remain generic so attackers cannot distinguish valid users from invalid users. Throttled users should see a plain message such as “Please wait a few minutes and try again.”

Use Rails conventions and the simplest durable implementation available in this app. Prefer Rails' built-in rate limiting if it fits the current Rails version and app setup. If not, use a small Rails-cache-backed throttle rather than adding a broad new dependency.

### Bootstrap setup recovery guard

Setup should remain available during true first-run setup and during partial failed first-run states, such as an organization without a user or a user without an organization.

Setup should not reopen unauthenticated admin creation merely because `installations.setup_completed_at` is blank when the app already has both organization and user data. That condition is treated as an operator recovery problem, not a browser setup flow.

### Session activity touch

When a valid signed session cookie resumes a session, update `sessions.last_seen_at` periodically. This records real use and prepares for later session/device management.

This pass should expire a session only after 180 days of inactivity. That is a stale-session cleanup rule, not a short hard timeout. Active officers should remain signed in as long as they keep using the app.

## Future Session/Device System

Create a roadmap entry and GitHub issue for the full session/device management system. Tracking issue: <https://github.com/AndreRobitaille/LegionPostTools/issues/1>.

That later work should include:

- A Settings › Security section listing signed-in browsers/devices.
- Last seen time, browser/user-agent summary, and approximate IP address for each session.
- Revoke one session.
- Sign out all other sessions.
- 180-day inactive session cleanup.
- Session revocation on risk events such as disabled users and future email/account changes.
- Optional step-up authentication for sensitive actions such as managing users/settings or finalizing official records.

## Testing

- Controller tests for throttled auth endpoints.
- Controller tests for setup remaining available in partial first-run states.
- Controller tests that setup does not reopen when both user and organization data already exist but `setup_completed_at` is blank.
- Controller/model test for `last_seen_at` being touched on resumed sessions.
- Static page/content assertion for the unsupported-browser page if practical.

## Acceptance Criteria

- Public auth endpoints are rate-limited with generic user-facing messages.
- The unsupported-browser page gives useful officer-facing upgrade guidance.
- Existing installations cannot be reclaimed through `/setup` just because the setup-complete flag is missing.
- Session activity is recorded, and sessions expire only after 180 days of inactivity.
- The full session/device system is documented in the roadmap and tracked in GitHub.
