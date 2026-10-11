# Current authority on delegated retries

Design for #92, discovered during #78/#84, October 10, 2026. Roles policy makes a
personal delegate follow its owner's current authority. An unchanged-app synthetic
request proves completed idempotent writes bypass that authority and replay private
working minutes after a dated Commander assignment expires. The retry does not mutate
minutes again. Active-account/token authentication alone does not cover duty loss.

## Contract and implementation

Before replaying a completed response, run the same action-specific current-authority
guards that normally run before the action. Register those existing guards with an
`authorize_with` callback declaration on API controllers. It installs the ordinary
Rails before callback and records that same callback for replay, with its `only`/`except`
action scope. Inherited minutes editing guards remain inherited; conditional Endeavor
creation still checks the original request's action parameter. The callback contains
the current policy, rather than copied capabilities or a permission fingerprint.

Keep authentication and active-token locking unchanged. Replay runs only registered
authority guards, stopping on a rendered denial. An action without such a guard fails
closed on replay. Record lookup, optimistic locking, state validation, mutation and
official-confirmation consumption remain part of first execution only. Replaying those
checks would incorrectly reject a valid receipt after deletion, attestation, or a changed
lock version and could defeat once-only behavior.

Calendar authority explicitly supplies the configured Post date in both paths: a replay
does not enter CalendarTimeZone's action wrapper, so it must not accidentally evaluate
the same guard using the server date. The broader differing date contexts on other
controllers are a separately tracked policy/consistency concern, not changed here.

Denial must return no cached private content and leave both records and the completed
execution unchanged. Restoring authority permits the original receipt again without
another write, audit event or official confirmation. A manual drafting grant does not
retain identity-bound official duties or conditional Endeavor creation authority.
No schema, grant resolver, policy, endpoint or UI changes are required.

## Verification

Retain all existing idempotency, token-revocation, state, foreign-scope and official
confirmation tests. Add representative real request/retry contracts for expired offices,
removed manual grants, composite calendar policy, conditional Endeavor creation,
official handoff/attestation and publication. Inventory routed API mutation actions so
unregistered future actions cannot silently bypass replay authorization. Prove permitted
retries still work after deletion and official state transitions and that restoring
authority retrieves the unchanged original receipt.

The original expired-office content failure is recorded in
`/tmp/legion-officer-original-query-safe.log`: 4 tests, 202 assertions, 1 failure, 0 errors,
0 skips on main `b47d10ee25788f01e4d497200b69b545d17a29be`; the other three role matrices
pass. Full ordinary and browser suites run serially on the final committed candidate,
with lint/security and exact-SHA CI before merge, followed by actual-main CI.
Use synthetic test records only; no paid AI, production work or deployment.
