# Connected Buddy Checks backend design

October 11, 2026. Source baseline `7f862d5a0b526380356463ef545553b58a810c9b`.
Implementation authorization is the supplied backend task; the companion mobile
contract is requirements plus proposed mechanics. Existing modified documentation
and the mobile handoff are preserved. No production or official-record changes.

## Boundaries and choices

Enabled human accounts receive the directory baseline and their own active Buddy
Check assignments. This does not broaden MembershipAccess, renewal or agent APIs.
New mobile endpoints accept only a dedicated OAuth bearer credential. Doorkeeper
provides authorization-code exchange, PKCE, hashed credentials, expiry and revocation;
existing browser passkey/email sign-in supplies human identity. Require S256, exact
registered callback, nonempty state, one registered public client and a configured
installation origin. No wildcard, implicit, password, client-credentials or agent
flow. Begin with 15-minute access credentials and browser reauthorization, without
refresh tokens: this uses established library behavior without inventing refresh
family replay semantics. The existing browser session makes reauthorization possible
without necessarily repeating sign-in. Device token revocation and browser token
management are required. The mobile client validates state and original origin.

`MOBILE_BUDDY_CHECK_ENABLED` is off by default. `MOBILE_CONTACT_EXPORT_ENABLED`
is separately off pending Post policy on personal copies. Client/callback and issuer
registration are deployment prerequisites. Suggestions use configurable 7/60-day
attempt/conversation intervals; they are working policy, not evidence of complete
history. Unknown remains unknown. No production settings are changed here.

Extend MembershipContact, not the roster: exact instants and IANA entry zones for
new mobile entries, date-only legacy entries, append-only replacement entries with
one successor and a stable root identity. Effective history is shared by mobile and
workspace calculations. Assignment years stay fixed; unassigned entries use event
Post-local year. Administrative reviews and not-attempted do not count as outreach.
No automatic phone-launch outcome. UUID operations are scoped to organization/user,
canonical-payload bound, serialized under the user lock, and atomically stored with
stable immutable receipts. Receipt replay rechecks current account and recipient
permission, but is not rejected merely because its own contact made outreach recent.

Caller-owned follow-ups are separate from contacts. Expected revisions and immutable
operation receipts audit creation, reschedule, completion and cancellation. Closing
one never creates a contact. Snoozes are personal, expiring and undoable with the same
retry/conflict rules. Cross-caller assignments, pauses, recent contact and open work
exclude suggestions. Search is server-filtered and capped; no roster bulk endpoint.

### Random choices with insufficient history — October 12, 2026

When no eligible person has rankable evidence, preserve `insufficient_history` and
include up to three distinct `random_candidates`, containing only `id`,
`first_name`, and `last_name`. Sample only after the existing access, self, caller
exclusion, personal snooze, eligibility and open-follow-up checks. Missing history
remains unknown; sampling never supplies an evidence reason or creates work.
An exhausted population has no choices. An evidence-ranked candidate keeps its
existing response and priority. This is an additive response field; no scope,
schema, permission, expiry or CSRF change is needed. The mobile app owns rendering
and must fetch a fresh preparation card before contact.

Use an injectable random source for deterministic synthetic regression tests.
Verify small and empty pools, distinct bounded identity-only choices, all existing
access/exclusion boundaries, unchanged evidence ranking, and read-only behavior.

Contacts projection uses explicit fields and separate names. Address components are
reviewed against a digest of the original flat roster address and source import;
changed sources invalidate the projection even if stale rows remain. Company is
configurable, never hard-coded. Address export initially requires full membership
access; assignments alone do not currently authorize address copies. This narrower
choice preserves existing policy until the Post explicitly grants a wider tier.
Personal contact edits have no write route to official Person records.

## Attendance and visual direction

Separate general-member registers attach to real Meetings, never minutes. Current
full-membership managers record an explicit membership coverage snapshot, individual
present/absent/excused/not-recorded statuses and a review note. Completeness requires
an explicit status for every covered member; missing rows are never absent. Saving
creates an immutable revision. Two distinct complete registers with explicit absences
can support a suggestion; latest revisions govern, officer roll call is unused.

Use The 1919 navy #0A2240, gold #C6A15B, cream #F4EEDD, paper #FBF7EC and ink
#1b222b. System sans for working controls and tracked labels; serif stays reserved
for official documents. Compose existing page-lead, section_header, stacked-form,
field and button components. Attendance's defining element is its visible coverage
statement beside completeness, with member/status rows stacking on phones. Body and
controls 16px minimum, helper text 14px, labels 13px. Authorization clearly names
Buddy Checks and personal contact-copy boundaries. Token management offers explicit
per-session revocation. Review desktop and 390px renders with synthetic data.

## Verification plan

Synthetic test DB only. Exercise actual sign-in continuation, callback/PKCE/code
replay/expiry, cookie CSRF and bearer separation; disabled users, role/assignment
changes; exact retries, changed payloads and concurrent requests; corrections driving
history/work/suggestions across years; follow-up lifecycle; exclusions without private
fields; incomplete/revised attendance and stale address provenance. Run focused tests,
full ordinary suite, relevant browser tests, lint/security/dependency checks. Record
blocked checks separately from product failures and do not infer deployment.

## Consent referrer policy correction

The October 11 native browser submission exposed a gap in the initial tests:
rendering consent and HTTP probes with a supplied Origin did not exercise the
browser's form navigation. `no-referrer` makes that navigation send `Origin: null`,
which Rails correctly rejects. Use `strict-origin` on authorization responses:
the browser retains its same-origin POST Origin while referrers reveal only the
origin, never the authorization path or query. `same-origin` would send the full
authorization URL to same-origin destinations, so it does not meet that privacy
requirement. `strict-origin` may disclose the origin to another HTTPS destination,
but omits referrers on HTTPS-to-HTTP downgrades. See
[MDN's policy and Origin behavior](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Referrer-Policy).

Keep `no-store`, normal CSRF tokens and Rails origin verification, including its
[null-Origin rejection](https://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection.html#method-i-valid_request_origin-3F).
No OAuth, session or client configuration changes are needed. Regressions must
click the real consent form with protection enabled and observe browser-generated
headers, plus deny missing/wrong tokens and unrelated/null Origins. The existing
consent layout and visual direction remain appropriate; this is a response-header
correction with no UI changes.

## Verification-driven refinements

The pre-existing documentation changes were committed externally during this task
as `845d17be4d5173a5dd8e31aae085fccade4569d7`. This task made no commit.
The implementation remains an uncommitted patch on that revision.

Receipt, attendance and address-review rows, and Buddy Check contact entries, are
append-only at the PostgreSQL boundary as well as in Rails. A database-maintained
address source version prevents a changed-then-restored flat address from reviving
an old reviewed projection. This also covers bulk roster updates. The independent
retry experiment uses a disposable, explicitly named test database and observes a
real waiting PostgreSQL writer; it is separate from transactional unit fixtures.

Ordinary expiry, explicit token revocation and disabled-account responses have
distinct error codes. The mobile adapter must not discard unfinished work merely
because a 15-minute credential expired. Other callers' administrative reviews and
purpose-permission records are excluded from caller-owned mobile event history and
cannot be corrected through this interface.

An agreed callback that is due lets its own caller prepare outreach despite the
ordinary recent-contact interval; pauses and another caller's assignment still
apply. Open callbacks stay out of new suggestions. Legacy date-only callbacks
remain independent scheduling evidence across years, with their date preserved
when event facts are corrected. They are not converted to fabricated due instants.
Invalid staff evidence forms retain entered values so a correction does not require
re-entering the attendance review or address source.

## Private LAN integration environment

The mobile integration request supplies the exact callback
`org.wipost165.buddychecks:/oauth/callback`. Use a separate named synthetic test
database and a foreground, TLS-only Puma process on the shared LAN. A short-lived
test CA signs the LAN-IP certificate; current device trust is limited to the
explicitly approved disposable simulator. Mac and physical-phone trust stores
remain unchanged. Do not change device trust remotely or bypass certificate
verification. Process-only test configuration enables CSRF, secure cookies, host
checking and disabled external mail/jobs. Keep keys, sign-in links and session
credentials in owner-only temporary files. Public connection details and observed
backend results belong in a separate integration handoff. That handoff records
reported native observations separately from backend checks and remaining device
verification.

## Post 165 production activation — October 12, 2026

Use the existing permanent origin `https://members.wipost165.org`, the public
client ID `org.wipost165.buddychecks`, and exact callback
`org.wipost165.buddychecks:/oauth/callback`. Retain 900-second credentials, S256,
explicit browser consent, strict-origin referrers and no refresh tokens.

Personal Contacts copies require the installation flag and the separate
`export_buddy_contacts` capability on every read. Administration, membership
leadership and assignments do not imply this capability. Grant it explicitly to
Andre during this authorized activation. Existing membership authority still
controls reviewed address fields; the export grant adds no roster or renewal access.
Session capabilities and preparation cards reflect the current export grant.
The existing Permissions form gets a Buddy Checks group and plain checkbox,
using The 1919 components and typography without a new screen. Verify the rendered
control at desktop and 390px, including later revocation with an existing token.

Andre's October 12 follow-up limits launch to himself. Require the separate
`use_mobile_buddy_checks` capability for OAuth, code exchange, every mobile API
request, browser Mobile sessions, general-member attendance and address-review
controls. Hide the three site links unless the feature is enabled and this current
capability exists. Evidence editing still also requires membership-manager authority.
Existing general membership/Buddy Check drive workflows remain available under their
current policy. Grant both pilot and export capabilities to Andre only; no officer,
assignment or administrator automatically receives either. Existing role-grant
controls can deliberately delegate them later. Removing pilot access denies the next
API request with the established 403 `account_unavailable` authority error, while
disabled accounts remain 401 and ordinary credential expiry stays distinct.

Add an operator task that validates configuration, registers the exact public
client without a secret, and grants only the requested user's export capability
in one transaction. Existing incompatible registrations fail without overwriting
them. Activation is explicitly selected for one release; ordinary releases never
restore a deliberately revoked permission.

The release entry point runs read-only production probes before and after the
deploy through its one persistent SSH connection. Report installation identity,
account availability, safe mail-provider settings, applied mobile migrations,
registered callback and grants. Compare server-computed counts and fingerprints
of roster, membership, financial and official-record tables; transfer no member
rows. Activation creates no checks, attendance, reviews, tokens or sign-in sessions.
Preserve unrelated work by releasing a clean copy of the reviewed commit.
