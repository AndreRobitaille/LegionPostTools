# Passkey refusal, saved state and recovery

Design for #104 under #84, initial source `b852211`, October 10, 2026.
Final candidate integrates verified main `a88f11e`; no authentication source changed
across the intervening scoped merges. Governing
authentication architecture requires active owners and actual WebAuthn verification.
The controller requests/verifies user verification and consumes the browser's issued
challenge. No runtime defect has been reproduced; the missing evidence is actual
cryptographic refusal and persisted state preservation.

Keep existing option/verification-argument tests: their explicitly captured user handle,
resident-key policy, exclusions, challenge/public key/counter and required verification
contracts detect adapter mistakes. They stub cryptography and cannot establish real
signature refusal. Keep generic disabled/unknown responses, rate limits, own/foreign
credential management, session reauthentication and all old assertions. Strengthen the
two existing generic refusals with unchanged saved credential/session state.

Add one bounded real FakeClient scenario to the existing enrollment-security file.
Register a real synthetic credential through current endpoints; for missing user
verification and a signed assertion with a different challenge, issue a new challenge
and submit the assertion. Check the original session graph and credential/use attributes
before asserting generic refusal. After each refusal request a fresh challenge and
prove valid authentication produces a fresh session for the registered owner, updates
the counter/use time and permits later protected Profile reading. Time control makes
recorded use changes deterministic; failed challenges may be consumed and are not
expected to survive. No mocks of credential verification in this scenario.

Retain separate enrollment freshness, challenge/session/purpose, other-user refusal and
denied-attacker-key cases; they protect registration and reauthentication boundaries.
Real browser virtual-authenticator enrollment at 1400/390/320px and personal-token
creation/reveal-once/back/revocation remain distinct from request evidence.

Temporarily relax only authentication's `user_verification: true` to false; the missing-
verification case must fail on changed session/credential state or actual acceptance.
Restore exact controller bytes in finally and prove clean focused checks. Do not change
registration verification. No application, policy, UI, cryptography or lifetime change
is proposed. Final committed ordinary/system suites serially, lint/security, fresh
review and exact-SHA/actual-main CI are required before merge. Synthetic test records
only; no production operations, member data or paid AI.


## Neighboring authentication source/assertion review

These source/assertion reviews started at `b852211`; final source is unchanged
on integrated `a88f11e`. They are not proof from test counts.
All existing cases/assertions stay; no removal or consolidation is justified.

| File | Distinct retained evidence and limit |
| --- | --- |
| `sessions_controller_test.rb` (17) | Real POST/code/email request, account-private known/unknown/disabled/provider-error results; GET/HEAD do not consume, stale forms preserve original cookie/session/proof and other unused link; actual sign-out plus stale-cookie later denial; request/consumption account/IP buckets differ. Direct helper setup does not prove sign-in. |
| `models/magic_link_test.rb` (10) | Independent digest-only secrets, one-time link/code cross-invalidation, grouped code formats, wrong browser, attempt budget, expired/disabled state, exact purpose/session binding. Crypto input contracts remain below actual mail/browser flows. |
| `models/magic_link_concurrency_test.rb` (1) | Real separate connections and simultaneous consumers yield one owner/one nil, persisted use time; nontransactional fixture cleanup distinct from serial once-only model cases. No injected thread scheduler. |
| `models/session_test.rb` (3) | Actual session destruction preserves completed official approval/revision/event, detaches pending confirmation and email challenge, and rejects nil/replacement-session use. Immutable official lineage cannot be replaced by generic sign-out status. |
| `mailers/magic_links_mailer_test.rb` (1) | Actual multipart addressing, code/link/expiry/plain-URL/same-browser text; does not claim live external delivery. |
| `controllers/passkeys_controller_test.rb` (13) | Explicit option/verification arguments, actual saved counter/use/session, own/foreign rename/remove, disabled/unknown sentinels and independent rate limits. Stubbed verification requires the separate real-signed refusal cases. |
| `controllers/passkey_enrollment_security_test.rb` (11 original) | Real signed registration; stale/legacy identity, duplicate/missing challenge, identity expiry/reproof, same-user different session, denied attacker key, email/existing-key recovery and foreign-user reauthentication. New authentication refusals complement registration boundaries. |
| `controllers/passkey_enrollment_reauthentications_controller_test.rb` (12) | Real mail/code/link consumption, same-session proof, GET confirmation, repeated-link refusal, foreign session/purpose, bearer exclusion, cancellation, expiring/oversized intent and saved nickname; provider seam restored in ensure. |
| `controllers/agent_access_reauthentications_controller_test.rb` (7) | Personal-token purpose and same-session identity, code/link cross-invalidation, foreign session/purpose and bearer exclusion; similar enrollment text has distinct purpose/destination semantics. |
| `system/authentication_entry_test.rb` (2) | Actual returning bookmarks/old links preserve the session; phone-width request/resend/newest-code sign-in and sign-out controls. Setup alone is not the exercised email request. |
| `system/passkey_enrollment_security_test.rb` (1) | Real virtual-authenticator WebAuthn, browser CSRF and email confirmation at 1400/390/320px; persisted nickname/credential, continued controls and no overflow. Restores origin/browser/forgery globals. |

Synthetic offline mail and WebAuthn are actual local boundaries; no provider or production
behavior is inferred. #102 separately covers personal credential primitive/precedence and
account/token screens; #105 records the website native-navigation inspector problem.
Future explicit Post-date authority remains #93, not silently resolved by these tests.


## Focused and controlled-fault evidence

New real signed refusal/recovery plus existing passkey requests pass 25 / 230 / 0
(seed13048, 3.06s). Relax only authentication verification, retaining registration's
required verification: the new test fails on changed persisted credential counter/use
metadata before a status assertion, 1 / 4 / one failure (seed19791, 0.86s). This is
regression sensitivity of the new test, not an existing application defect. Exact
controller bytes restored in finally: SHA256
`0f294f8cbc59388603843a59c9fdf075fe92bb52e21ddf8876c358cf08a6b7a2`.
Restored neighboring authentication requests/models/mailer pass 76 / 801 / 0
(seed21953, 3.41s). No verification fault remains. Main #106 was subsequently integrated
as `8a603bb`; fresh integrated focused/browser and final committed serial suites/CI are
still required. Full source review is distinct from real-browser execution; no auth
policy, external mail provider, production or clipboard claim is made.


## Fresh-browser refinement and integrated evidence

Each real authentication refusal/recovery loop now calls `reset!` before requesting
its challenge. Enrollment's session remains saved but its cookie cannot supply later
Profile access. Both signed refusals preserve the saved credential/session graph;
each valid fresh challenge creates the registered owner's new session, records actual
counter/use/identity timestamps and permits later Profile reading. Existing assertions
and registration/reauthentication contracts are retained.

On integrated main `a88f11e`, neighboring requests/models/mailer pass 76 runs / 801
assertions, zero failures/errors/skips (seed21487, 3.31s). Relaxing only authentication
user verification again fails the refined scenario on persisted credential metadata
before status: 1 / 4 / one failure (seed53734, 0.83s). Exact controller SHA256 above
was restored in finally. Restored passkey requests pass 25 / 230 / 0 (seed64993,
1.59s), and both changed Ruby files lint clean. No experimental fault remains.

Real existing authentication-entry, virtual-authenticator enrollment and personal-token
browser journeys pass 4 / 102 / 0 (seed36848, 13.09s) on preceding verified main
`66e8c8a`; the intervening title-scope change affects none of those flows. Enrollment
covers 1400/390/320px, actual identity confirmation, nickname preservation and saved
credential creation. Desktop and 390px continued-enrollment captures inspected manually:
1919 typography is readable, input/action labels wrap clearly and there is no horizontal
overflow. The final committed full system suite must repeat these journeys on the final
revision. Clipboard content and external delivery remain unverified.

Commands use `/tmp/legion-overnight-env`, explicit synthetic test database
`postgresql:///legion_passkey_review_test`, and single-worker browser execution.
Focused neighboring files: sessions controller, magic-link/session models, magic-link
concurrency, multipart mailer, both passkey request files, enrollment reauthentication
and agent-access reauthentication. Focused final passkey command:
`bin/rails test test/controllers/passkeys_controller_test.rb test/controllers/passkey_enrollment_security_test.rb`.
No tests are removed or consolidated. Final committed ordinary/system serial suites,
repository security/lint, complete diff review and candidate/actual-main CI remain
required before merge.
