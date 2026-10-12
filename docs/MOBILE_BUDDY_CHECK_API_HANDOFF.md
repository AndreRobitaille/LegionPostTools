# Mobile Buddy Check API handoff

Prepared October 11, 2026; production preparation updated October 12.
The original local evidence below predates production activation. The current
release and iPhone connection handoff is
[Production readiness](MOBILE_BUDDY_CHECK_PRODUCTION_READINESS.md).

The later [private LAN integration handoff](MOBILE_BUDDY_CHECK_LOCAL_INTEGRATION.md)
records the running synthetic HTTPS origin, the mobile project's exact callback,
public client ID, test-certificate trust steps and observed live protocol results.
It adds test infrastructure, not a production deployment or a new API contract.

## Source and scope

Initial source review: `7f862d5a0b526380356463ef545553b58a810c9b`.
Current base: `845d17be4d5173a5dd8e31aae085fccade4569d7`. The pre-existing
membership/help documentation edits were committed externally during this task;
this implementation made no commit. The untracked
`docs/BUDDY_CHECK_MOBILE_APP_HANDOFF.md` was preserved. This document describes the
additional uncommitted source, migrations and tests, not either commit alone.
Use `git status --short` and `git diff` together with new files before integrating.

Implemented: human OAuth/PKCE access, bounded member search and preparation cards,
exact event facts and legacy date precision, immutable corrections and receipts,
caller-owned follow-ups/snoozes, server suggestions, general-member attendance
review, and separately gated Contacts export with reviewed address provenance.
There is one Person roster and one MembershipContact history. Renewal and delegated
agent APIs keep their distinct authentication and authorization.

The [design](MOBILE_BUDDY_CHECK_DESIGN.md) records decisions against current source.
No Apple source, real member data, outreach, paid calls, messages to another task,
commits, pushes, merges, production configuration or deployment were performed.

## Activation and human authentication

Both feature flags default off. Set these **only for a deliberately configured
installation** after its policy and callback decisions:

| Setting | Meaning |
| --- | --- |
| `MOBILE_BUDDY_CHECK_ENABLED=true` | Enables native authorization, exchange and mobile API. |
| `MOBILE_BUDDY_CHECK_ISSUER` | Exact origin, e.g. `https://members.example.org`; HTTPS required in production. No path/query/userinfo. Request origin must match. |
| `MOBILE_BUDDY_CHECK_CLIENT_ID` | UID of the single registered public Doorkeeper application. |
| `MOBILE_CONTACT_EXPORT_ENABLED=true` | Installation gate for personal Contacts copies; each human also needs `export_buddy_contacts`. Default off. |
| `MOBILE_CONTACT_COMPANY` | Company for copies; default organization name. First installation may explicitly configure `American Legion Post 165`. |
| `BUDDY_CHECK_ATTEMPT_DAYS` | Working recent-attempt interval, default 7 elapsed days; clamped 1–365. |
| `BUDDY_CHECK_CONVERSATION_DAYS` | Working reached-conversation interval, default 60 elapsed days; clamped 1–730. |

Register a `Doorkeeper::Application` with `confidential: false`, `scopes:
"buddy_check"`, a descriptive name and **one exact** `redirect_uri`. Its generated
UID is public configuration, not a shared credential. Application administration
and token-introspection interfaces are not provided to mobile clients. There is
no client secret in the app. Registration is an operator deployment prerequisite,
not something a phone or ordinary member may perform through the API.

Use `ASWebAuthenticationSession` and the existing passkey/email browser sign-in:

1. Generate a cryptographically random verifier of 43–128 RFC 7636 characters,
   S256 challenge (base64url without padding), and unpredictable state of at least
   32 characters (maximum 512). Persist the expected state/issuer for this attempt.
2. Open `GET /oauth/authorize` on the configured issuer with `client_id`,
   `response_type=code`, `redirect_uri`, `scope=buddy_check`, `state`,
   `code_challenge`, and `code_challenge_method=S256`.
3. Existing human sign-in returns to the **Connect Buddy Checks** consent form.
   Its CSRF-protected `POST /oauth/authorize` issues an external 302 redirect with
   `code` and the original `state`. GET alone never grants consent. Invalid client,
   exact callback, issuer, challenge, response type or state returns 400 locally,
   without redirecting to the supplied URI. Cancel returns to the Post dashboard.
4. The app must validate the exact expected state and original installation before
   exchanging. POST form-encoded to the original issuer's `/oauth/token`:
   `grant_type=authorization_code`, `client_id`, `redirect_uri`, `code`,
   `code_verifier`. Do not follow an exchange redirect to a different origin.
5. Successful exchange is 200 with standard Doorkeeper fields:
   `access_token`, `token_type: "Bearer"`, `expires_in: 900`,
   `scope: "buddy_check"`, `created_at` (Unix seconds). Credentials are hashed in
   the database; authorization codes expire after 10 minutes and are single-use.
   Wrong verifier/callback, expired/reused code or disabled account returns 400
   `{"error":"invalid_grant", ...}`. Invalid public client returns 401
   `invalid_client`; disabled configuration/wrong issuer returns 503.

**Deliberate proposal change: no refresh tokens in this version.** Access lasts
15 minutes. Reopen the external-browser authorization flow when it expires; the
existing browser session may avoid another passkey/email ceremony, but consent is
still explicit. There is no custom refresh-family protocol or 30-day mobile
credential. Keep unfinished work while ordinary expiry is resolved for the same
installation and human. A later refresh design requires separate implementation
and replay-family verification; the mobile adapter must not assume it exists.

`POST /oauth/revoke` accepts form fields `client_id` and `token`. It returns 200
`{}` for a valid client's revoked/unknown token and revokes that token only.
Browser **Your profile → Mobile sessions** lists unexpired sessions by ID and
connection time; CSRF-protected `DELETE /mobile/sessions/:id` revokes an owned
session and redirects 303. Native `GET /api/mobile/v1/session` reports the matching
session ID. Reauthorizing creates another short-lived session; tokens are not
reused. Disabling the human account blocks every subsequent mobile request and
code exchange. Current roles/assignments are looked up on each request.

The library choice follows [Doorkeeper PKCE guidance](https://doorkeeper.gitbook.io/guides/ruby-on-rails/pkce-flow) and [hashed credential support](https://doorkeeper.gitbook.io/guides/security/token-and-application-secrets); behavior was also checked against the locked 5.9.9 source.

Every mobile flow requires the current `use_mobile_buddy_checks` pilot capability.
Initial production launch grants it to Andre only; no member, assignment, office or
administrator receives it implicitly. OAuth consent and code exchange require it.
Removing it immediately denies an existing token with 403 `account_unavailable`;
disabled accounts remain 401. Mobile sessions and the two staff evidence controls
are hidden and their direct URLs denied without pilot access. Evidence editing also
requires current full membership access. Existing role-grant controls allow deliberate
delegation later; this release creates no office-level pilot grant.

The native interface uses bearer headers only: cookies and `AgentAccessToken`s
cannot authenticate it, and mobile credentials cannot authenticate existing agent
APIs. Browser authorization and session management retain Rails CSRF protection.
Canonical issuer checks apply to authorization, exchange and every mobile request;
no cross-origin CORS access is configured. OAuth authorization responses use
`Referrer-Policy: strict-origin`: referrers omit authorization paths/queries while
normal browser form submissions retain the same-origin Origin required by CSRF
protection. All private API/OAuth responses use `no-store`. The original
`no-referrer` policy caused native consent to fail; see the browser regression and
current service status in [the local integration handoff](MOBILE_BUDDY_CHECK_LOCAL_INTEGRATION.md).
Codes, tokens, state, name queries, phone/address fields and notes are filtered from
Rails parameter logs. Do not add client-side body/credential logging.

The Apple task still must select/register its signing team, bundle ID and callback
scheme (or HTTPS associated domain with AASA/entitlements) and verify it on a real
device. `org.example.buddy:/callback` is synthetic test configuration only. Never
infer a production domain or signing entitlement from it.

## Mobile conventions, status and identity

Prefix: `/api/mobile/v1`. Send `Authorization: Bearer …` and JSON for writes.
No `Idempotency-Key` header is used here: each mutation requires its own JSON
`operation_id` UUID. Route and session determine actor, organization and purpose;
clients cannot supply financial, renewal or officer-action fields.

IDs are database integer identities, opaque to the app. Scope every cached/journal
identity by issuer/installation and human. Contact `id` is the stable original
logical ID; `source_id` identifies the immutable revision row. Contact revisions
start at 1. Follow-up/snooze `revision` is optimistic `lock_version`, starting at 0.
Expected revisions are required on corrections/changes/undo.

List responses are `{"items":[...],"next_cursor":"123"}`; terminal cursor is
null. `limit` defaults to 25, maximum 50; `cursor` is the returned decimal source
row ID, initially omitted. Results are ordered by source row ID ascending. This
is live keyset pagination, not a frozen roster snapshot. Corrections can appear
on later pages with an existing logical ID: upsert by logical ID. Restart a fresh
read when reconciling changed data. There is no total count or unrestricted roster
endpoint. Search requires a 2–80 character name query and escapes SQL wildcards.

All instants are ISO 8601 with an explicit offset/Z. Responses emit UTC with six
fractional digits. `entry_zone` must be a real IANA zone. The Post timezone derives
`occurred_on` and the unassigned event year; the original entry zone is preserved.
New mobile events require an exact instant, cannot be future-dated and must fit
the existing membership-year validation. Legacy entries return `precision: "date"`,
`occurred_at: null`, `entry_zone: null`; midnight is never fabricated.

Mobile errors have `{"error":{"code":"…"}}`:

| HTTP | Codes / meaning |
| --- | --- |
| 401 | `expired_session`: reauthorize, keep journal; `revoked_session`: confirmed token revocation; `account_unavailable`: human removed/disabled; `invalid_session`: missing/unknown/wrong credential or unregistered client. Unknown credentials alone do not establish confirmed revocation. |
| 403 | `contact_paused`, `export_disabled`, `export_not_permitted`, or `account_unavailable` if authority changes during a write. |
| 404 | `not_found`: inaccessible/removed/deceased/unassigned hidden person, another caller's record, or absent receipt. These are deliberately indistinguishable. |
| 409 | `operation_payload_conflict`, `stale_revision`, `follow_up_closed`. Refresh current state; preserve the rejected local draft for a deliberate new operation. |
| 422 | `invalid_request`: missing fields, unknown top-level fields, invalid UUID/zone/instant/outcome, invalid pagination/search, or invalid follow-up/snooze range. Nothing is partially saved. |
| 503 | `unavailable`: mobile feature/issuer unavailable. Suggestion service does not invent an empty roster in this case. |

OAuth endpoints use OAuth string errors, not the nested mobile error schema.

## Routes and schemas

Unless stated otherwise, GET succeeds with 200. Writes below return 201 with a
stable receipt, including exact retries. A receipt records accepted server work;
it does not claim a phone call or device notification occurred.

| Method and route (after prefix) | Request | Response |
| --- | --- | --- |
| `GET /session` | None | Installation `{id,issuer,name,timezone}`, human `{id,name}`, `session_id`, `expires_at`, capabilities `{buddy_checks,contacts_export,refresh:false}`. |
| `GET /buddy-checks/people` | `q`, optional `limit,cursor` | Page of `{id,first_name,last_name}` only. |
| `GET /buddy-checks/people/:id` | None | Identity, `phone,email`, `assignment_ids`, `export_available`, `eligibility`, `coverage`. Phone/email are null when outreach is currently excluded. Export availability reflects the installation flag and current human export grant; export endpoint additionally checks the recipient and field tier. |
| `GET /buddy-checks/suggestion` | Optional `exclude_ids[]`, max 50 positive IDs | Candidate described below, or `{state:"exhausted"|"insufficient_history",coverage}`. |
| `POST /buddy-checks` | `operation_id,person_id,facts`; optional `assignment_id,follow_up` | Receipt with `contact`, optional `follow_up` (null when omitted). |
| `POST /buddy-checks/:id/corrections` | `operation_id,expected_revision,facts` | Receipt with new effective `contact`; original and prior rows remain immutable. |
| `GET /buddy-checks/receipts/:operation_id` | None | Original accepted receipt under current authority; 404 if missing. |
| `GET /buddy-checks/mine` | Optional `limit,cursor` | Page of caller-owned effective contacts across all years. |
| `GET /buddy-checks/:id/revisions` | Optional `limit,cursor` | Page of caller-owned original and correction facts for one logical contact. |
| `GET /buddy-checks/follow-ups` | Optional `limit,cursor` | Page including open and closed caller-owned follow-ups. |
| `POST /buddy-checks/follow-ups` | `operation_id,person_id,due_at,entry_zone` | Receipt with independent `follow_up`. No contact is created. |
| `POST /buddy-checks/follow-ups/:id/changes` | `operation_id,expected_revision,action`; reschedule also needs `due_at,entry_zone` | Receipt with `follow_up`. Actions: `reschedule`, `complete`, `cancel`. |
| `GET /buddy-checks/snoozes` | Optional `limit,cursor` | Page including active, expired and undone caller-owned snoozes. |
| `POST /buddy-checks/snoozes` | `operation_id,person_id,until_at` | Receipt with `snooze`. |
| `DELETE /buddy-checks/snoozes/:id` | JSON `operation_id,expected_revision` | Receipt with undone `snooze`. No physical row deletion. |
| `GET /people/:id/contact-export` | None | Explicit field projection, version and provenance described below. |

`facts` contains `channel`, `outcome`, `occurred_at`, `entry_zone` and optional
`notes` (string, maximum 2,000 characters). Channels are `phone`, `text`,
`in_person` (map mobile “visit” to this). Outcomes are `reached`, `no_answer`,
`message_left`, `wrong_number`, `not_attempted`. Map “connected” to `reached` only
on the caller's explicit report. `not_attempted` does not count as an attempt.
Launching Phone, returning from it, completing a follow-up, consent or permission
restoration creates no conversation. Renewal outcomes are rejected.

Corrections require full replacement event facts, not a patch. When the original
was date-only, a correction may instead supply `occurred_on: "YYYY-MM-DD"` and
omit both exact fields, preserving date precision. Never send both an instant and
an independent occurred-on date. Legacy `callback_requested` events can be read
and corrected, but the new mobile contact outcome set keeps scheduling separate.
Contact responses also include `legacy_follow_up_on` (ISO date or null). Correcting
that event preserves its separate legacy callback date. These date-only callbacks
participate in coordination and remain managed through the existing Membership
workflow; they are not silently converted to exact-instant mobile follow-up rows.
Administrative reviews, contact permission records and renewal contacts cannot be
corrected through this interface.

Assignment IDs must belong to the current caller, person, organization, active
Buddy Check drive and current inclusive dates. An assigned event retains that
drive's year even on correction. Omit assignment ID for a directory-based check;
its year is the event's Post-local calendar year. Immutable contact revisions are
also used by membership worklists and history; exact same-day events use event
instants when ordering work, with legacy paper/unknown-time tie rules retained.

`follow_up` on contact creation is `{due_at,entry_zone}`. Scheduling/rescheduling
requires a future instant at most two years ahead. Returned follow-ups are
`{id,person_id,contact_id,due_at,entry_zone,status,revision}`; `contact_id` may be
null for an independent follow-up. Status is `open`, `completed` or `cancelled`.
Closed follow-ups cannot be reopened/rescheduled; schedule a new explicit follow-up.
Closing does not create or alter contact history. There is no notification-delivery
claim or reminder push provider.

Snoozes return `{id,person_id,until_at,cancelled_at,revision}`. Until must be future
and at most 90 days ahead. An unexpired row with null cancellation defers that
person for this caller only. Multiple snoozes can exist; undo each active ID that
the app created. This does not reserve or suppress anyone for other callers.

### Synthetic contact and retry example

All names/IDs below are illustrative; use the fixture's actual returned IDs.

```json
{
  "operation_id": "11111111-1111-4111-8111-111111111111",
  "person_id": 42,
  "facts": {
    "channel": "phone",
    "outcome": "no_answer",
    "occurred_at": "2026-10-11T15:30:00-05:00",
    "entry_zone": "America/Chicago",
    "notes": "Synthetic attempt; no message left."
  },
  "follow_up": {
    "due_at": "2026-10-13T15:30:00-05:00",
    "entry_zone": "America/Chicago"
  }
}
```

```json
{
  "operation_id": "11111111-1111-4111-8111-111111111111",
  "accepted_at": "2026-10-11T20:31:00.000000Z",
  "state": "accepted",
  "contact": {
    "id": 81, "source_id": 81, "person_id": 42, "revision": 1,
    "channel": "phone", "outcome": "no_answer", "precision": "instant",
    "occurred_at": "2026-10-11T20:30:00.000000Z", "occurred_on": "2026-10-11",
    "entry_zone": "America/Chicago", "membership_year": 2026,
    "notes": "Synthetic attempt; no message left.", "legacy_follow_up_on": null,
    "recorded_at": "2026-10-11T20:31:00.000000Z"
  },
  "follow_up": {
    "id": 14, "person_id": 42, "contact_id": 81,
    "due_at": "2026-10-13T20:30:00.000000Z", "entry_zone": "America/Chicago",
    "status": "open", "revision": 0
  }
}
```

Operation UUIDs are unique within **organization + human**, across all these
mutations and across renewed mobile sessions. Canonical fingerprints include the
operation kind/target and full accepted payload. Object key order is irrelevant;
scalar representations and supplied fields must remain identical on retry. The
user-row lock serializes retries, recipient lock coordinates mobile writers, and
a database unique index backs the receipt. Mutation and receipt commit in one
transaction. A failed validation/conflict leaves no receipt or partial follow-up.

After a lost response, GET the receipt using the same human and installation. A
200 means accepted; retain its revision/source identity. A 404 means unknown or no
current access, not permission to change payload or create a new operation ID.
Recheck the person and retry the original body/key only when currently permitted.
A changed payload/key reuse returns 409. Corrections require a new operation ID.
Receipt replay rechecks enabled human, current directory/assignment authority,
deceased/removed status and contact pause. A later recent-contact exclusion does
not invalidate the receipt for the contact that caused that exclusion. Older
accepted receipts stay stable after correction; fetch effective history/revisions
to reconcile the latest projection.

## Permissions and privacy

| Actor | People / contacts | Follow-ups / corrections | Contacts export, if flag enabled | Staff evidence |
| --- | --- | --- | --- | --- |
| Enabled ordinary member | Directory-visible people; own actual checks, no renewal-manager access | Own permitted records only | Directory names, phone, email, company; no address | No |
| Enabled assigned caller | Same plus their currently active Buddy Check assignments, including an otherwise hidden expired recipient | Own recorded checks and physical contact events transcribed for their assignments; never another caller's records | Directory tier only; an assignment alone does not authorize permanent export of a hidden person or mailing address | No |
| Current full-membership manager | Mobile uses the same directory/own-assignment selection; existing Membership workspace retains broader officer authority | Own mobile records only; officer status does not expose others' mobile notes through these routes | Reviewed address components additionally, for a mobile-permitted person | General-member attendance and address review |
| Other officer/historical officeholder | Ordinary baseline unless separately assigned/granted current authority | Same ownership rules | Ordinary baseline | No implicit access |
| Disabled human, agent token or website cookie | No mobile API access | None | None | Existing browser policy remains separate |

Contacts export additionally requires the current `export_buddy_contacts` capability
for every tier in the table. Assignments, current offices, membership access and
`manage_settings` do not imply this grant. Administrators maintain it in the existing
person's Permissions form under Buddy Checks. Removing it immediately disables
export for an existing mobile token, while leaving outreach and renewal permissions
unchanged. `session.capabilities.contacts_export` reports the current gate and grant.

Every mobile projection excludes National member number/status, renewal/payment
facts, financial entries, other callers' names/notes and support history. A minimal
aggregate eligibility reason can reveal that outreach is recent or coordinated;
it never returns the underlying other-caller record. There are no roster-edit or
message-send operations. Notes belong to the caller's check; keep clinical or
detailed hardship information out of general Buddy Check notes.

The staff HTML entry points are:

- `GET /membership/buddy-attendance`: up to 100 recent past meetings.
- `GET/POST /membership/buddy-attendance/:meeting_id`: view/save a register revision.
- `GET/POST /membership/buddy-addresses/:person_id`: review/save address components.

All require current full-membership-manager authority and normal browser CSRF.
Membership navigation and the member workspace link to them. No agent-token
substitution or mobile officer write shortcut is added.

## Eligibility, history and attendance

Reopen the person's card immediately before a Phone/text/visit handoff and after
background return. Eligibility returns `{eligible,reason,checked_at,expires_at}`;
the display expires after one minute and is **not a reservation**. Possible reasons:
`contact_paused`, `assigned_elsewhere`, `open_follow_up`, `recent_attempt`,
`recent_conversation`. Deceased/removed recipients and lost selection authority
return 404 instead. Recent-attempt checks take precedence over conversation reasons.
An own future follow-up blocks new outreach; an own due follow-up can be prepared,
including inside ordinary recency intervals, while contact pauses and another
caller's assignment still deny it. Legacy date callbacks become due on the Post's
local date without inventing a due instant.
Other callers' open follow-ups exclude outreach regardless of due date. All open
follow-ups stay out of new suggestions. Physical events that actually happened may
still be recorded despite a *recent-contact* coordination exclusion; selection
permission and purpose pause are always rechecked. This preserves truthful history
when offline work overlaps. It does not authorize stale outreach.

All-year **effective** Buddy Check facts feed suggestions. Actual physical
`callback_requested` legacy contacts, wrong numbers, messages and unanswered calls
are attempts; only `reached` establishes a conversation. Administrative entries and
not-attempted do not. Exact recency uses elapsed time; date-only sources conservatively
exclude the entire boundary day. Personal snoozes and bounded client exclusions are
applied after permission filtering. Ties are deterministic: two explicit absences,
then oldest recorded contact date, then person ID. There is no automatic cycling.

Contact coverage is always `partial`; missing history is `unknown`. This installation
has no source establishing complete historic contact capture, so there is no claim
of “never contacted” or “known empty.” With permitted candidates but no recorded
contact/attendance evidence, the state is `insufficient_history`; when none remain
eligible, it is `exhausted`. The mobile adapter must preserve this distinction.

The insufficient-history response additionally includes `random_candidates`: up
to three distinct identity-only objects (`id`, `first_name`, `last_name`). The
server samples the same permitted, eligible population after caller exclusions,
self exclusion, personal hiding, pauses, assignment coordination, recency and all
open-follow-up checks. Small populations return fewer choices. Missing evidence
remains unknown; this field supplies no history reason or contact details.
Ranked `candidate` and `exhausted` responses omit the field. Repeated reads can
produce different samples and never create a check, follow-up, snooze, assignment
or receipt. Existing clients may ignore it; new clients must tolerate omission,
validate identities/count/exclusions, and fetch a fresh preparation card before
contact. No new scope, authorization flow or schema is required.

```json
{
  "state": "insufficient_history",
  "coverage": {
    "contact_history": "partial", "missing_history": "unknown",
    "attendance": "explicit_registers_only", "checked_at": "2026-10-12T18:00:00Z"
  },
  "random_candidates": [
    {"id": 42, "first_name": "Alex", "last_name": "Example"},
    {"id": 43, "first_name": "Taylor", "last_name": "Example"}
  ]
}
```

See the [October 12 change and clock handoff](MOBILE_BUDDY_CHECK_RANDOM_CHOICES_HANDOFF.md)
for verification and deployment status; repository implementation is not proof of
production availability.

Candidate example:

```json
{
  "state": "candidate",
  "person": {"id": 42, "first_name": "Alex", "last_name": "Example"},
  "reason": "recorded_contact_is_older", "reason_on": "2026-07-03",
  "attendance": {"coverage": "unknown", "meetings": []},
  "eligibility": {"eligible": true, "reason": null,
    "checked_at": "2026-10-11T20:00:00.000000Z", "expires_at": "2026-10-11T20:01:00.000000Z"},
  "coverage": {"contact_history": "partial", "missing_history": "unknown",
    "attendance": "explicit_registers_only", "checked_at": "2026-10-11T20:00:00.000000Z"}
}
```

General-member attendance is separate from `MinutesAttendanceEntry` officer roll
call. A new register covers the current directory-visible roster-backed members;
the officer must explicitly review that named coverage for the actual past,
non-cancelled meeting. It cannot automatically reconstruct a historical roster.
Coverage IDs stay fixed across that register's revisions. Every covered member has
`present`, `absent`, `excused` or `not_recorded`. Complete requires no unrecorded
rows and an officer coverage note. Incomplete/reopened registers are unknown, even
when some individual rows say absent. New coverage changes or unsupported historical
cohorts must remain incomplete rather than being guessed.

For a person, the latest revisions of the latest two covered, actual meetings must
both be complete and explicitly absent. The reason becomes `two_recorded_absences`
with a Post-local reason date and meeting IDs/instants/register revisions. Missing
registers, missing rows, excused status and officer roll call never imply absence.
No accepted minutes, attestation, approval or meeting heading is rewritten.

## Contacts export and address provenance

Read the export immediately before native creation/update; reassess on foreground
return. The app must separately ask the user to make the copy, link the native
record, review field conflicts and preserve unrelated native fields. Personal
edits have no write-through route to Post records. Copies may sync in their chosen
Contacts account and cannot be promised retractable on sign-out.

Example for an officer with a reviewed street but unknown remaining components:

```json
{
  "person_id": 42, "source": "legion_post_tools/person/42",
  "version": "sha256-of-current-projection-and-authority",
  "fields": {"first_name": "Alex", "last_name": "Example",
    "company": "Example American Legion Post", "phone": "+1-202-555-0100",
    "email": "alex@example.test", "address": {"street": "12 Example Way"}},
  "permitted_fields": ["first_name", "last_name", "company", "phone", "email", "address"],
  "address_coverage": "reviewed_components", "address_review_id": 3,
  "checked_at": "2026-10-11T20:00:00.000000Z"
}
```

Address keys, when reviewed and known: `street,city,state,postal_code,country`.
Missing fields are omitted, not guessed. Ordinary members receive `address: {}`,
`address_coverage: "not_permitted"`, no address-review ID and no address permission.
Managers with no current reviewed source receive `address_coverage: "unknown"`.
The original flat `roster_address` is never exported as a complete postal address.

Address reviews preserve actor, time, source note, original-source digest and
components. The digest includes original flat address, import time and a database
source version. Changing/importing a source invalidates old reviews; changing text
back does not revive them. Export version changes with fields/authority/review.
The adapter must fetch again, not treat an old version as indefinite permission.
Assignment-only address export from the proposal is deliberately unavailable until
the Post approves such a permission tier.

## Repeatable synthetic setup and verification

Do not use development data; that database can contain real members. The fixture
script refuses every database except `legion_buddy_mobile_test`, requires test
mode and an empty database, and never resets it. It sends no email.

```sh
DATABASE_URL=postgresql:///legion_buddy_mobile_test RAILS_ENV=test bin/rails db:create db:schema:load
DATABASE_URL=postgresql:///legion_buddy_mobile_test RAILS_ENV=test bin/rails runner test/manual/setup_buddy_mobile.rb
```

Run schema load only for a newly created empty synthetic database. The script
writes `/tmp/legion-buddy-mobile-fixture.json` with mode 0600: public client UID,
IDs, issuer, callback and short-lived synthetic browser sign-in links. Open it
locally, never commit or share its sign-in links. Launch the server with that UID:

```sh
DATABASE_URL=postgresql:///legion_buddy_mobile_test RAILS_ENV=test \
MOBILE_BUDDY_CHECK_ENABLED=true MOBILE_CONTACT_EXPORT_ENABLED=true \
MOBILE_BUDDY_CHECK_ISSUER=http://localhost:3107 \
MOBILE_BUDDY_CHECK_CLIENT_ID='<public client UID from fixture>' \
bin/rails server -b 0.0.0.0 -p 3107
```

The server binds off-box, but issuer must match the URL the device actually uses.
For a remote simulator/phone, replace the issuer with a reachable, appropriately
protected test origin and create local fixture links for that origin. No real-data
storage, physical-device callback, dialing or Contacts permission acceptance is
implied. Fixture phone numbers are fictional; do not dial them.

Fixture expectations:

| Person | Expected behavior |
| --- | --- |
| Alex Example | Old exact contact; eligible suggestion after Morgan. |
| Blair Example | No history; unknown, never “never contacted.” |
| Casey Example | Recent conversation/attempt excludes new suggestion. |
| Dana Example | Purpose paused; card hides contact actions, writes/replays forbidden. |
| Evan Example | Expired directory-hidden person visible only to assigned Jamie while the Buddy Check drive remains active. No assignment-only Contacts copy. |
| Frankie Example | Open future follow-up excludes new suggestions. |
| Morgan Example | Two explicit complete general-member absences support first suggestion. |
| Harper Example | Additional untouched person for unknown-history/mobile write checks; no contact history. |

Caller: Jamie Caller; reviewer: Riley Reviewer. Synthetic sources are named
`Example American Legion Post`, not the actual Post's member data.

Core repeatable commands:

```sh
RAILS_ENV=test bin/rails db:migrate
PARALLEL_WORKERS=1 bin/rails test test/controllers/api/mobile test/controllers/mobile_authentication_test.rb test/services/buddy_checks
SYSTEM_TEST_CAPTURE_DIR=/tmp/buddy-check-screens PARALLEL_WORKERS=1 bin/rails test test/system/buddy_checks_test.rb
PARALLEL_WORKERS=1 bin/rails test
PARALLEL_WORKERS=1 bin/rails test:system
RAILS_ENV=test bin/rails zeitwerk:check
bin/rubocop
GEM_SPEC_CACHE=/tmp/buddy-gem-specs bin/brakeman --no-pager
bin/bundler-audit check --update --database /tmp/buddy-ruby-advisory-db
```

The retry-race script refuses any DB except a newly created, empty
`legion_buddy_race_test`:

```sh
DATABASE_URL=postgresql:///legion_buddy_race_test RAILS_ENV=test bin/rails db:create db:schema:load
DATABASE_URL=postgresql:///legion_buddy_race_test RAILS_ENV=test bin/rails runner test/manual/buddy_check_retry_race.rb
```

It observes the second PostgreSQL connection waiting on the first writer, then
asserts identical receipts, exactly one accepted contact and no mutation from
changed-payload reuse. These scripts deliberately refuse re-seeding an existing
populated fixture. Dispose of only these synthetic databases explicitly after use;
never reset development/production to make a test pass.

Expiry/revocation/callback/replay cases use actual OAuth HTTP requests in
`test/controllers/mobile_authentication_test.rb`. Contact interruption/conflict,
scoping, stale address sources and all mobile mutation denial use
`test/controllers/api/mobile/buddy_checks_test.rb`. Evidence tests cover all-year
history, corrections, exact-vs-date precision, effective ordering, incomplete
attendance, source immutability and unchanged accepted synthetic minutes.

## Migrations, compatibility and remaining acceptance

`20261011210000_add_mobile_buddy_checks.rb` creates three standard Doorkeeper tables,
adds optional exact facts and correction links to MembershipContact, and creates
receipt/follow-up/snooze/attendance/address-review tables. No old event timestamps
are backfilled and no new roster database is created. Financial tables are unchanged.

`20261011211000_preserve_buddy_evidence.rb` adds a source-version counter to Person,
a trigger advancing it on source changes, and append-only triggers for Buddy Check
contact rows, operation receipts, attendance revisions and address reviews. Existing
Rails immutability remains; direct SQL cannot rewrite those saved facts either.
Normal roster imports remain supported. Account/person/meeting deletion may now be
refused by evidence foreign keys, as expected for retained provenance. A meeting
with an attendance register is no longer an empty deletable meeting. Deploy schema
before enabling the code; do not roll these migrations down after real use without
a separate retention/migration plan.

The browser sign-in continuation is scoped to the mobile flow; normal passkey
response shape is preserved. Membership Buddy Check work/history now use effective
corrections across years and separate mobile follow-ups. Other renewal/financial
policy and old agent idempotency remain intact.

Before real use, Andre/Post still needs to approve personal Contacts copies,
confirm any future assignment-only/address tier, choose company and suggestion
intervals, confirm who maintains general-member attendance, and register the mobile
client/callback/issuer. Feature and export gates remain off by default.

The October 12 production-readiness request authorizes Andre's export grant and
the Post 165 settings in `config/deploy.yml`. Migration
`20261012120000_add_buddy_contact_export_permission.rb` admits the new capability
and pilot capabilities in the existing database constraints and grants nobody automatically. Use
`BUDDY_CHECK_ACTIVATE_EMAIL=commander@wipost165.org bin/release push-deploy` for this
explicit activation. The operator task registers the exact public client and
adds only that human's export grant. Ordinary releases never regrant it.

Not implemented/verified: refresh tokens, complete historical contact coverage,
historical membership reconstruction, automatic messaging/phone outcome detection,
notifications or delivery, mobile protected storage/adapters, device Keychain and
journal purging, native Contacts account conflict handling, Apple entitlements,
physical phone call return/VoiceOver, or production deployment. The mobile issues
remain open for connected and physical-device acceptance.

## Executed results

Checks ran against synthetic test data on the source described above. Passing local
checks do not establish CI, deployment, provider delivery or real-device acceptance.

- Final full ordinary suite: **1,410 tests, 13,940 assertions, 0 failures,
  0 errors, 0 skips** (`PARALLEL_WORKERS=1 bin/rails test`, seed 18958).
  This pass includes the final callback refinements; system tests ran separately.
- Full Chromium system suite: **90 tests, 5,340 assertions, 0 failures, 0 errors,
  0 skips**. This includes real browser attendance saves/revisions, structured-address
  review, consent display and owned-session revocation. Desktop 1400px and narrow
  390px screenshots were inspected; controls meet the 16px floor and the new pages
  have no horizontal overflow. Screenshots are in `/tmp/buddy-check-screens/`, named
  `buddy-attendance-*`, `buddy-address-*`, `buddy-consent-*` and `buddy-sessions-phone`.
- Callback/evidence regression pass on a separate synthetic database: **12 tests,
  62 assertions, 0 failures, 0 errors**. The two new callback cases first failed,
  then passed after correcting due-callback eligibility and cross-year legacy work.
- Real PostgreSQL retry race: **passed**. The second writer was observed waiting;
  both submissions returned the identical receipt with exactly one contact and
  operation. Changed-payload reuse conflicted without altering accepted work.
- RuboCop: **580 files, no offenses**. Its default cache was read-only; it completed
  without caching. Brakeman: **0 errors, 0 security warnings**. The scan used the
  writable temporary gem-spec cache shown above.
- Bundler audit: **no vulnerabilities found**, using advisory database revision
  `a6847b0651a702488f5844081e848dd1ec9dbf1d` (updated October 10, 2026).
  Zeitwerk eager loading passed. Routes compiled, all four JSON examples parsed,
  local document references resolved, and `git diff --check` passed.
- The isolated mobile fixture server and browser smoke check used synthetic people
  only. A separate cancellation/retry check confirmed that closing a follow-up
  created no contact and removed its open-work exclusion. Temporary servers,
  browser session, three synthetic fixture databases and generated sign-in links
  were cleaned up; the repeatable scripts remain in `test/manual/`.

Intermediate failures exposed and corrected a normal-passkey response-shape
regression, lost staff form selections on validation, an undersized checkbox label,
and the callback eligibility gaps above. Existing test inventories were updated for
the separate mobile credential surface and new database triggers. Address GET tests
now compare reloaded database baselines because the source-version trigger changes
the persisted value during setup. Initial missing locked gems, sandbox cache access
and a test-schema/code timing mismatch were resolved before the final checks.

There is no CI or production evidence from this task. Real-data enablement and the
mobile/device acceptance items above remain outstanding.
