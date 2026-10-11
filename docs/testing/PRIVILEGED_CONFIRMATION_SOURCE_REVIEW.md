# Privileged confirmation and invitation source review

Bounded #84 source/assertion review at15ce51b, October11,2026. Current
MINUTES_APPROVAL_AND_ATTESTATION.md governs audited handoff, human attestation, later
meeting approval and corrected-text locking. This complements #104 authentication
and #78/#81 routed authority proof; it does not replace those independent contracts.
Every old case/assertion remains. No code or test edit, fault or production inspection
belongs to this source-only slice.

## Whole existing request scopes

| Exact file | Retained distinct evidence and limits |
| --- | --- |
| `test/controllers/official_action_reauthentications_controller_test.rb` (9) | Actual prepared stale-session handoff; queued synthetic mail/code actual purpose/session and consumed confirmation; link GET/POST separation with no pre-POST revision/consumption; named confirmation page/form; changed-text refusal with draft/no revisions/no consumption; stubbed passkey handoff with saved counter/revision; direct Adjutant attestation without Commander handoff; sign-out retaining other session's confirmation and stale-cookie later denial; disabled/inactive Session destruction with nullable confirmation provenance. Retain all variants; direct session setup is not sign-in proof, supplied passkey verify=true is orchestration rather than cryptographic authentication, and current saved status predicates alone do not inspect every immutable payload. |
| `test/controllers/passkey_invitations_controller_test.rb` (1) | Anonymous actual dismiss DELETE must redirect to sign-in. Retain this distinct authentication boundary. It does not prove a signed-in person can dismiss the card, that the browser follows the form, or that a new session offers the invitation again. Source controller only sets current cookie-session state; a gap is not a demonstrated runtime bug. |

`OfficialActionReauthenticationsController` actual challenge consumption checks the same
user and purpose/session, and confirmation lookup is user/session-scoped. Confirmation
source snapshots action digest/version, validates session owner, locks confirmation/
consumption, retains provenance and dispatches the action to MeetingMinutes. No dedicated
OfficialActionConfirmation model-test file was located; its contracts are exercised
through minutes/request/system tests and remain to be mapped completely. Do not infer
all expiry/session/consumed/payload variants from the nine request counts. Existing
real MinutesApprovalFlow, AccountMenu and OfficialActionPrefetch browser journeys
supply separate interaction/record/sign-out evidence recorded in the overnight matrix.
No safe duplication or deletion is demonstrated.


The invitation's eligibility is actually computed in DashboardController (no passkeys
and no current-session dismissal flag), and its real button is Not now. No positive
located browser assertions exercise it; bounded follow-up#117 records the exact real
sign-in/dismiss/unchanged identity/later-read/new-session contract before any test edit.
This is missing evidence, not a demonstrated application failure.


Subsequent controller routing found the existing positive invitation request in the
separate DashboardControllerTest: invite stays hidden after dismissal within the session.
It performs actual DELETE then GET and preserves useful card absence. Retain and reuse
that case; #117 concerns independent saved identity, later protected reading and real
browser/new-session interaction, not absence of every positive request. The same whole
Dashboard file has20 distinct setup/recovery,180-day expiration/resumed touch, meeting/
activity eligibility/Post-date/ongoing-event, passkey-present/invitation and email mismatch/
remind suppression/fresh request-session cases. Request new-session helpers are separate
from real browser sign-out/sign-in. No consolidation or test deletion.


Whole existing Dashboard20 cases are also indexed in [SOURCE_REVIEW_CASES.md](SOURCE_REVIEW_CASES.md),
with exact names/pinned lines for the separate positive dismissal detector and all other
variants. Actual-main15ce51b CI38118516754 executes these unchanged request scopes;
no fresh cryptographic verification or complete confirmation-model proof is claimed.
Follow-up#117 has independently reviewed saved-state and real-browser work; it remains
unmerged at this source note. Its proposed tests reuse the existing positive case.
