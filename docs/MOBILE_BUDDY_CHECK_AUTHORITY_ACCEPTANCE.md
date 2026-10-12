# Buddy Checks live authority and attendance acceptance

Prepared October 12, 2026. **Ready at the documented initial state.** Local
synthetic fixtures only; no deployment, commit, push or real data. No native
authority/attendance transition is claimed by this handoff.

## Public setup and current services

| Setting | Actual value |
| --- | --- |
| New issuer / origin | `https://192.168.37.41:3444` |
| Public client ID | `Ocja_43C84cZXkPbrdZS26r8cmV_5h8ydCkSEYhFIik` |
| Exact callback | `org.wipost165.buddychecks:/oauth/callback` |
| Scope / client authentication | `buddy_check`; public client, no shared secret |
| Flow | Human email/code or passkey sign-in, explicit consent, S256 PKCE |
| Access lifetime | 900 seconds; no refresh token |
| Installation | Synthetic Authority American Legion Post; ID `1`; `America/Chicago` |
| New database | `legion_buddy_authority_test` |
| New service | Detached Puma, `0.0.0.0:3444`, PID `411992` |
| Health | `GET /up`: HTTP 200; TLS verification result `0` |
| Original service | Port `3443`, PID `3842497`, unchanged; database `legion_buddy_mobile_test` preserved |
| Rehearsal | Port `3445` stopped after verification; `legion_buddy_authority_verify_test` retained with its evidence |

This is a new installation identity. Do not reuse the original instance's client
ID or certificate, or equate installations merely because both local database
organization IDs are `1`. Preserve the app's exact issuer/state/callback checks.

The new CA/server certificates expire **October 19, 2026, 11:42:30 UTC
(6:42:30 a.m. America/Chicago)**. New CA SHA-256 fingerprint:

```text
49:20:25:9F:8B:67:B8:E3:7A:EC:51:34:45:52:40:24:45:41:0C:58:37:44:76:7B:5F:E9:F5:E3:04:29:EC:97
```

Public certificate files on the backend host:

```text
/home/andre/Development/LegionPostTools/tmp/buddy-authority-public/buddy-authority-test-ca.cer
/home/andre/Development/LegionPostTools/tmp/buddy-authority-public/buddy-authority-test-ca.pem
```

The CA signing key was never written to disk. Server keys and configuration are
owner-only in `/tmp/legion-buddy-authority/`; none appear in this handoff. Transfer
only the public CA to the explicitly approved disposable simulator, verify the
fingerprint, and install/trust it there for the next run. The previously removed
CA was for the old instance. Mac and physical-phone trust remain unchanged.
There is no ATS exception, TLS bypass, public tunnel or DNS change.

Backend health check, requiring no trust-store change:

```sh
curl --cacert /tmp/legion-buddy-authority/ca.pem https://192.168.37.41:3444/up
```

## Accounts, recipients and initial records

| Account | Email | User/person ID | Initial authority |
| --- | --- | --- | --- |
| Jamie Caller | `jamie@example.test` | `1` | Ordinary mobile caller; Avery assignment `1` |
| Riley Reviewer | `riley@example.test` | `2` | Mobile reviewer; membership position assignment `1` |
| Pat Steward | `pat@example.test` | `3` | Backend fixture steward; separate position assignment `2` |

Only Jamie and Riley use the private email transport/mobile sign-in. Pat is used
by backend controls and retains authority independently of Riley's export-tier
test. No real mail or external background job is sent.

| Case / recipient | Person ID | Initial state |
| --- | --- | --- |
| Avery Assignment | `4` | Directory-hidden expired roster person; readable only through Jamie's active Buddy Check assignment `1`. No contact or receipt. |
| Parker Pause | `5` | Directory-visible, outreach permitted. Jamie's accepted contact `1` is dated July 4, 2026; receipt `1` retained. |
| Cameron Coordination | `6` | Directory-visible, eligible and unassigned. Riley's old contact `2` is dated July 4, 2026; its private note/history is unavailable to Jamie. |
| Emerson Export | `7` | Directory-visible. Address review `1` is current and available to Riley. No contact. |
| Taylor Attendance | `8` | Directory-visible, no contact history, no attendance registers. Missing history is unknown. |

Drive `1` is Buddy Check purpose, membership year `2026`, active through
October 26, 2026. The certificate expires sooner. Initial state is exactly two
contacts/two operation receipts, one active outreach assignment, one reviewed
address, zero follow-ups, zero snoozes, zero attendance registers and zero minutes.
No controlled transition has been run against this database; its checkpoint
journal does not yet exist.

Parker's accepted baseline operation UUID is
`97c4d40e-4e5c-4ec0-a763-37c7630e5c00` (Jamie). Cameron's baseline operation is
`d83ebceb-1c61-417d-a259-bd3a1ae741d4` (Riley). These identify existing synthetic
receipts, not bearer credentials. Never reuse them for a new draft.

## Fresh email/code sign-in

Start the native app at the new issuer with the new public client ID. In its
ephemeral authentication browser, enter Jamie's or Riley's email. The normal
sign-in form writes a fresh, browser-bound code to a private backend file:

```sh
# On the backend host, after requesting the email in that same browser:
cat /tmp/legion-buddy-authority/mail/1.json  # Jamie
cat /tmp/legion-buddy-authority/mail/2.json  # Riley
```

Use only the latest requested code in that browser, then explicitly select
Connect Buddy Checks. Codes are single-use and expire after 15 minutes. Do not
paste inbox contents, links, codes or tokens into this handoff or shared logs.
Existing SSH access can read these files; the Mac's intermittent 1Password SSH
signing problem is separate from the healthy HTTPS service. Do not change backend
TLS or use production to work around it.

## Backend checkpoint commands

Run these only in the backend session, after the mobile session names the actual
screen/draft/review it has reached. No scheduled/background transition is armed.
The checkpoint text is an observation supplied by the mobile session, not a claim
to invent. Commands print current IDs/revisions and append a private checkpoint
journal. Read status before proceeding after any interrupted command.

```sh
cd /home/andre/Development/LegionPostTools
ruby test/manual/buddy_authority.rb status
ruby test/manual/buddy_authority.rb advance ACTION '<actual mobile run and observed checkpoint>'
```

Replace `ACTION` with the exact action from the tables below. No HTTP fixture
control endpoint exists. The controls call existing membership and attendance
workflows, use a separate steward, and check expected state/revisions. They cannot
target the original database. Restorations retain ended assignment/position rows;
permission and attendance changes append evidence.

Within each case, use fresh requests under the same active mobile session where
possible. A 401 `expired_session` is an expiry result, not an authority result;
reauthenticate and report it separately. Complete the reviewer tier transition
within one session to establish live authority refresh.

### Member access: Avery, Jamie

| Mobile checkpoint → backend action | Expected fresh response / persisted result |
| --- | --- |
| Initial Avery card and retained unsent draft | Person GET 200, `eligible:true`, assignment IDs `[1]`. Search includes Avery. Export is already 403 `export_not_permitted`: an assignment never grants permanent Contacts export. |
| Draft is safely retained → `member_end` | Ends the active Jamie/Avery assignment. Person/export GET and a submitted contact POST return 404 `not_found`; search 200 has no Avery. No accepted contact/receipt for the draft UUID. |
| Denial and receipt/SQL reconciliation observed → `member_restore` | Creates a new authorized assignment; the ended row stays ended. Person/search recover. Export returns 403 `export_not_permitted` again. The unsent/rejected UUID remains unknown until an explicit client retry. |
| Mobile has observed restoration and explicitly retries | A valid unchanged omitted-ID body and UUID can POST 201 `accepted`; receipt GET 200 and exact retry return the same receipt and one logical check. No backend control submits the draft. |

**Current native omitted-ID contract:** `POST /api/mobile/v1/buddy-checks` accepts
the omitted `assignment_id` used by `ConnectedDraft.mutation()`. Current selection
authority is still checked; an active assignment is how hidden Avery is selected.
The accepted contact's `membership_assignment_id` stays null, and its membership
year comes from the event's Post-local date. This does not bypass assignment loss.
Restoring access permits an explicit retry of the **same body and UUID**, with no
assignment field added. This behavior was verified over HTTPS; no backend behavior
was changed to accommodate the client.

The earlier backend rehearsal also exercised the optional explicit-ID variant:
an ended ID continues to return 404 even after a different assignment is created.
That rehearsal refreshed the explicit ID after proving the rejection, while
preserving its operation UUID. It is separate from the native omitted-ID path.
Do not rewrite an uncertain native pending body/UUID to imitate that probe.
Generic membership-workspace API requirements are also separate from this mobile
endpoint's optional assignment field.

### Purpose-specific pause: Parker, Jamie

| Mobile checkpoint → backend action | Expected fresh response / persisted result |
| --- | --- |
| Parker card/export review or retained unsent draft | Person GET 200, eligible, phone/email present. Export 200 with directory-tier fields. Existing contact/receipt `1` remains accepted. |
| Screen/draft ready → `pause_on` | Appends a `buddy_check` administrative `do_not_contact` record. Person GET stays 200 with `eligible:false`, `reason:"contact_paused"`, null phone/email. Identity-only search still includes Parker. Export and contact POST return 403 `contact_paused`. |
| Denial/reconciliation observed → `pause_restore` | Appends `contact_permission_restored` through the membership officer workflow. Card/export recover. No retained draft is automatically saved; only an explicit mobile retry may accept it. |

An **existing accepted** Parker receipt GET returns 403 while paused, then the
same original receipt returns 200 after restoration. An **unknown draft UUID**
receipt GET returns 404 even during the pause. These are different situations:
403 must never be interpreted as proof that an accepted operation is absent.
Existing own accepted history remains evidence; the pause does not erase it.

### Assignment coordination: Cameron, Jamie versus Riley

Isolate Cameron using suggestion `exclude_ids[]=1&exclude_ids[]=2&exclude_ids[]=3&exclude_ids[]=4&exclude_ids[]=5&exclude_ids[]=7&exclude_ids[]=8`.
This is seven exclusions, below the 50-ID bound.

| Mobile checkpoint → backend action | Expected fresh response / persisted result |
| --- | --- |
| Cameron candidate/card visible | Suggestion 200: candidate ID `6`, reason `recorded_contact_is_older`, reason date `2026-07-04`. |
| Candidate/card ready → `coordination_assign` | Assigns Cameron to Riley. Jamie's card stays 200 but is ineligible with `assigned_elsewhere`, phone/email null. Isolated suggestion 200 is `exhausted`. |
| Deferral observed → `coordination_end` | Ends Riley's assignment. Jamie's eligibility and the isolated candidate recover. |

Jamie's `mine` contains no Cameron event, and reading Riley's contact `2` revisions
returns 404. No assignment or suggestion reveals Riley's note. Directory Contacts
export still returns 200: coordination is not a purpose pause. Current mutation
policy permits recording an event that actually occurred; this case does not
claim an `assigned_elsewhere` mutation denial. Do not record a new Cameron check
until the deferral/recovery observations are complete, because new recency would
mask the intended condition.

### Export tier: Emerson, Riley

| Mobile checkpoint → backend action | Expected fresh response / persisted result |
| --- | --- |
| Native Contacts review open with a fresh export | Export 200, `address_coverage:"reviewed_components"`, review ID `1`, permitted fields `first_name,last_name,company,phone,email,address`. Reviewed address: street `24 Example Lane`, city `Example City`, state `WI`, postal code `00000`, country `US`. |
| Review open → `tier_remove` | Ends only Riley's membership position assignment `1`. Same token/session export remains 200; permitted fields omit `address`, `fields.address` is `{}`, `address_coverage:"not_permitted"`, review ID null, version changes. |
| Reduced projection and disabled/cleared native address save observed → `tier_restore` | Adds a new Riley position assignment. The same reviewed address/projection recovers; the original review is unchanged. The original version may return because the authorized fields are identical again. |

Installation capability `contacts_export:true` remains true; it is not a per-field
authority decision. Fetch the current export. Native Contacts writes are local to
iOS, so preventing a stale open review from saving removed fields must be observed
in the mobile app. There is no server Contacts-write POST to reject. Pat retains
authority throughout, keeping the other fixture controls independent.

### Attendance evidence: Taylor, Jamie

Use `GET /api/mobile/v1/buddy-checks/suggestion` with `exclude_ids[]` set to IDs
`1,2,3,4,5,6,7`, leaving only Taylor (`8`). Keep Taylor free of new contacts,
assignments, pauses, follow-ups and snoozes until all stages are observed.

Meetings are stable: `1` starts `2026-09-22T18:00:00Z`; `2` starts
`2026-10-07T18:00:00Z`. Both are actual synthetic membership meetings, with no
minutes. New register coverage is the explicitly reviewed IDs `5,6,7,8`.

| Mobile checkpoint → backend action | Latest register state | Expected isolated suggestion (HTTP 200) |
| --- | --- | --- |
| Initial unknown screen | No registers | `insufficient_history`; missing history unknown, no absence reason |
| Initial unknown observed → `attendance_incomplete` | Meetings 1/2 revision 1; Taylor says absent but both registers incomplete; other rows not recorded | `insufficient_history`; individual absent rows do not make complete evidence |
| Incomplete result observed → `attendance_first_absence` | Meeting 1 revision 2 complete/absent; meeting 2 revision 1 incomplete | `insufficient_history`; one qualifying absence is insufficient |
| Single-absence result observed → `attendance_two_absences` | Both meetings revision 2 complete/absent | Candidate ID `8`, reason `two_recorded_absences`, `reason_on:"2026-10-07"`, coverage `explicit_absences`, evidence meetings `[2,1]`, revisions `[2,2]` |
| Dated two-absence reason observed → `attendance_present` | Meeting 2 revision 3 complete/present | `insufficient_history`; absence reason disappears |
| Corrected presence observed → `attendance_excused` | Meeting 2 revision 4 complete/excused | `insufficient_history`; excused is not absence |

Earlier registers remain unchanged. The final sequence has six rows: meeting 1
revisions 1/2 and meeting 2 revisions 1/2/3/4. These steps do not create contacts,
receipts, minutes, officer roll calls or artificial historical completeness.

## Rejected saves and unknown operations

For **each** rejected save, retain the original operation UUID and exact pending
body on the mobile side. Record whether the client stopped before POST (for
example, after a fresh 404 card) or sent a POST and received a mutation response.
An absent database row alone cannot distinguish those paths or prove that no
request is still in flight. Do not generate another UUID to hide uncertainty.

The mobile session uses its current human credential to read:

```text
GET /api/mobile/v1/buddy-checks/receipts/<original-operation-uuid>
```

The backend session separately runs this read-only reconciliation, replacing all
three arguments with the actual actor, recipient and original UUID:

```sh
ruby test/manual/buddy_authority.rb reconcile 1 4 '<original-operation-uuid>'
```

The command prints matching operation rows/accepted contact IDs and current
recipient contact IDs/revisions/outcomes, without notes or tokens. It rejects
non-fixture identities and mismatched recipients. A known rejected Avery/Parker
POST leaves zero operation rows for that UUID and no new physical contact row.
Parker's separate administrative pause/restoration rows are expected and must not
be mistaken for a submitted mobile check.

After restoring authority, repeat the receipt read before any retry. Unknown
remains unknown until resolved; do not delete or rebuild the pending operation.
Only an explicit mobile retry may create the check. Confirm POST 201, receipt GET
200, exact retry equality, one operation row and one logical check for that UUID.
All earlier accepted records and register revisions must remain intact. Report
401/403/404 responses according to their actual meaning, not as interchangeable
proofs of nonacceptance.

## Verification and safeguards

- Focused suite:
  `bin/rails test test/controllers/mobile_authentication_test.rb test/controllers/api/mobile test/services/buddy_checks test/controllers/buddy_evidence_review_test.rb`
  passed **31 tests, 251 assertions, zero failures/errors/skips** in the ordinary
  isolated test database.
- Real HTTPS rehearsal on port 3445 passed all five transitions and **63 explicit
  acceptance assertions** in its completed continuation. Both humans used the
  real email/code, consent and S256 flow; wrong verifier and code replay were
  denied. Denied saves used the normal receipt route plus uncached SQL. The
  omitted-ID path preserved exact body/UUID across withdrawal/restoration and
  created one check on explicit retry. The same Riley session saw the reduced
  export tier. Earlier accepted contacts/receipts and attendance rows were compared
  whole-row and remained unchanged.
- The first rehearsal stopped after an accepted explicit-ID POST because its
  separate Rails runner reused a cached count. Direct SQL showed one accepted
  row/receipt. Query caching was disabled and the accepted UUID/body was recovered
  from its receipt/record and exactly replayed without duplication. No fixture or
  accepted evidence was reset. A subsequent handbook-file encoding error stopped
  before further case changes; binary-safe storage resolved that probe issue.
- `ruby test/manual/buddy_authority.rb verify-initial` then passed **22 initial-state
  HTTPS assertions** on the actual port-3444 instance. Both accounts signed in;
  all five initial cards, assignment export denial, reviewed export, coordination
  suggestion and unknown attendance matched. Whole-row checks for eleven fixture
  model types matched before/after. Only authentication sessions/codes/tokens were
  created; successful probe tokens were revoked.
- Four guard checks rejected mutation verification on the live fixture, rerunning
  the consumed rehearsal, targeting the original database with the authority
  helper, and opting the ordinary test database into the HTTPS integration mode.
  Setup refuses a populated fixture rather than resetting it.
- RuboCop passed all **seven** changed/new Ruby files; whitespace/reference checks
  passed. No production runtime code, schema, API permissions or native code was
  changed. Existing browser coverage/consent fix remains in place; no new native
  browser or Contacts result is inferred from these HTTP probes.
- Before/after read-only counts and whole-row fingerprints matched for **all 72
  public tables** in `legion_buddy_mobile_test`. Its process, client registration,
  private configuration and accepted mobile evidence were left intact.

The authenticated caller's current `GET /api` handbook was read in the rehearsal.
Its private copy includes browser CSRF material and is not a handoff artifact.
HTTP probes supply Origin explicitly and validate certificates; they establish
backend protocol results, not browser-generated headers or native screen behavior.

Changed paths for this task:

- `docs/MOBILE_BUDDY_CHECK_AUTHORITY_ACCEPTANCE.md`
- `test/manual/buddy_authority.rb`
- `test/manual/buddy_authority_control.rb`
- `test/manual/buddy_authority_fixture.rb`
- `test/manual/buddy_authority_puma.rb`
- `test/manual/verify_buddy_authority.rb`
- `test/manual/verify_buddy_authority_initial.rb`
- `test/manual/buddy_mobile_environment.rb` (only the explicit three-database allowlist)

## Process operation, restoration and cleanup

The new port-3444 process is detached from this task's shell, not installed as a
boot service. It may stop at host reboot. Private environment, TLS key, inbox,
fixture metadata, PID and server log live in `/tmp/legion-buddy-authority/`.
`checkpoints.jsonl` is created only when a controlled action actually runs.

Before any stop, confirm the current listener/PID; do not rely on a copied old PID:

```sh
ss -ltnp 'sport = :3444'
cat /tmp/legion-buddy-authority/server.pid
# Only after confirming that it is the new authority service:
kill -TERM <confirmed-authority-service-pid>
```

Restart with existing data/configuration (leave the terminal open):

```sh
cd /home/andre/Development/LegionPostTools
ruby test/manual/buddy_authority.rb server
```

No `setup` or changing `verify` command should be rerun against a used fixture.
Read `status` first. The explicit `--rehearsal` profile is port 3445 and a different
database; its completed evidence is retained and its server is stopped.

During acceptance, perform the named restoration steps after the mobile session
has observed each denial. Attendance ends with appended corrected evidence; it is
not reset to missing. Accepted mobile checks are retained. After Andre finishes,
remove this new CA from the disposable simulator, stop only this instance, and
dispose of these two new databases/runtime directories only with explicit cleanup
authorization. Do not drop or re-seed `legion_buddy_mobile_test`, change port 3443
or port 3000, or alter Mac/physical-phone trust.

## Native evidence boundary

The mobile session reports prior evidence for sign-in/restoration, accepted
recording/correction, follow-ups, snooze, lost-response receipt recovery,
revocation/natural expiry, cross-caller deferral and private-history separation,
plus an 80-response HTTPS privacy check on the original fixture. Its latest run
also reports a real 15-minute phone-only snooze after natural 900-second session
expiry, notification-tap sign-in returning to Frankie's still-open follow-up, and
dismissal surviving restart. The mobile session reported unchanged whole-row Post
fingerprints and removal of its temporary simulator/CA. Those are reported mobile
results, not tests rerun here. None establishes live authority or attendance
changes in this new fixture; those native checkpoint tests remain next.
