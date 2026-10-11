# Personal token refusal and retained account boundaries

Design for #102 under #84/#81, October 10, 2026, source `4d7f67f`. Current personal
authentication checks the actual HMAC and active owner. This is a test-coverage gap,
not a demonstrated vulnerability: malformed/expired/revoked/disabled cases cannot
establish refusal of an active, correctly shaped token with the right public ID and
a different valid-hex secret.

Strengthen the existing model denial test with that case. Capture the result, compare
persisted token attributes before asserting refusal, then retain all old negative
states. A one-character deterministic hex change guarantees a different secret without
depending on chance. Keep recognizable issuance, digest-only storage, actor revocation
and last-use throttling tests: their distinct invariants remain useful.

Strengthen the existing API invalid-bearer/valid-cookie test with actual readable
synthetic private content, a well-formed wrong secret, unchanged token/use metadata and
content exclusion before 401. Keep the malformed-cookie refusal. Authentication and
current grants are separate; current-authority/expiry request matrices remain.

Retain personal UI request tests for own lists/readonly instructions, recent-human
creation, expiry allowlist, one-time/no-store plaintext and foreign revocation denial.
Retain administrator listing/revocation without reveal/mint and ordinary-member denial.
The website-token model's correct-shape wrong-secret case, fixed Post authority and
overlapping replacement have separate value; do not consolidate credential types.
Existing real browser token create/reveal-once/back navigation/revocation and human
reauthentication coverage remains rather than treating direct session helpers as sign-in.

Temporarily remove only `valid_secret` from the personal authentication guard in a
bounded finally-restored fault. The strengthened model/request tests must fail on
changed persisted use metadata or exposed private content/refusal; the real application
never changes. Check exact restored bytes and clean focused behavior. No cryptography,
owner policy, current grants, UI or token lifetime change is proposed.

Before merge, document focused/fault evidence, review intended changes, and require
final committed ordinary/system suites serially, lint/security, exact-SHA and actual-main
CI. Other authentication files remain explicitly deferred until reviewed. Synthetic
test records only; no production operations, real member data or paid AI.


## Initial model evidence

Correct application with new wrong-secret case: 4 / 23 / 0 (seed45760, 1.72s).
Remove only `valid_secret` from the authentication guard: 1 / 2 / one failure
(seed44095, 0.55s) on changed saved use metadata, before nil/status assertions. Finally
restored exact model SHA256
`83245346397165c589e4aa0ce48f87399733840fbd25a1259ff8fe73f7a2adc4`.
At this initial model stage the API wrong-secret case awaited integration of #99;
subsequent request evidence is recorded below. The original malformed, expired,
revoked, disabled and throttled-use variants remain unchanged.


## Actual cookie/bearer refusal and restored neighbor evidence

The request case has now integrated #99's retained receipt assertions; they are unchanged.
On main66e8c8a, changed model and complete existing officer requests pass33 / 206 / 0
(seed10925,2.81s). Real cookie reading first proves the fixed private Endeavor text is
available to that session. A correctly shaped active personal token with its actual
public ID but a guaranteed different hex secret must preserve all saved token attributes,
exclude that private text and return401; the original malformed-bearer case remains.
Removing only valid_secret fails this routed case on changed saved use metadata before
content/status1 / 5 / one failure (seed15039,1.07s). Exact model SHA above restored in
finally; clean model/officer requests33 / 206 / 0 (seed14700,2.61s). No application fault
or cryptography change remains. Final integrated source now `877c18e`; the complete credential/request focus passes
43 tests / 286 assertions (seed33457,3.31s). Final committed serial suites/security/exact
candidate/main CI remain required.

## Complete retained personal credential components

| Exact file | Retained distinct evidence and limit |
| --- | --- |
| `test/models/agent_access_token_test.rb` (4) | Recognizable actual issuance/authentication, digest-only stored values/display hint, malformed/expired/revoked/disabled/wrong-secret refusal, actual actor revocation and throttled successful use. Saved wrong-secret metadata catches guard bypass before nil. Current owner grants are a separate routed contract. |
| `test/controllers/agent_access_tokens_controller_test.rb` (5) | Actual own list versus foreign absence; own readonly operator instructions and Profile destination; recent human confirmation for creation; lifetime allowlist; actual one-time/no-store plaintext and later list exclusion; own confirmation/revocation versus foreign404 preserving token. Direct Session helper is not browser sign-in proof. |
| `test/controllers/admin/agent_access_tokens_controller_test.rb` (2) | Actual manual-administrator list without secret, saved revocation actor, missing foreign mint route preserving tokens; ordinary-member denial. Administrator oversight differs from personal credential issuance and does not create delegated authority. |
| `test/models/website_access_token_test.rb` (3) | Existing correct-shape wrong secret, inactive/expired/revoked/digest/last-use contracts, fixed Post publisher authority and overlapping replacements retained. Personal delegation differs from a Post website connection; no consolidation. |
| `test/system/agent_access_tokens_test.rb` (1) | Real magic-link confirmation followed by create/reveal-once/back/own revoke/desktop-phone navigation retained, separately executed during #104 browser verification. Visible copy control is not clipboard-content proof. |

The officer API file retains every existing request assertion; this change reviews its
specific invalid-bearer/cookie case and does not declare all API mutation variants complete.
Other authentication components reviewed separately under#104 remain intact. No safe
redundancy or test deletion is demonstrated.


Fresh real browser token journey on877c18e:1 /15 /0, seed14838,3.47s, through actual
magic-link confirmation/create/reveal-once/back/revoke at desktop and390px. Focused
RuboCop two changed Ruby files and diff whitespace checks pass. This visible copy control
still does not prove clipboard contents; #105 remains open. Full final committed checks
and CI are a subsequent required gate, not inferred from this focused evidence.
