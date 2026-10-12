# Native reminder acceptance: Quinn Reminder

Prepared October 12, 2026 for the explicitly approved synthetic reminder test.
This extends the existing port-3444 authority fixture. No production work or
application/API/schema changes are involved.

## Intended workflow and evidence

Add one directory-visible synthetic recipient, Quinn Reminder, and one independent
Jamie-owned follow-up through `BuddyChecks::Operations.schedule`. The initial due
time is October 13, 2026 at 3 p.m. America/Chicago (`2026-10-13T20:00:00Z`), with
4 p.m. (`2026-10-13T21:00:00Z`) reserved for the later reschedule checkpoint.
The follow-up remains open at revision 0 until the native session confirms a real
scheduled alert. Creating, rescheduling, or completing this independent follow-up
must never create a Buddy Check/contact.

At `reminder_reschedule`, require the actual native checkpoint, preserve the
follow-up identity and its scheduling receipt, and use the domain workflow to
reschedule revision 0 to revision 1. At `reminder_complete`, require native refresh
and restart evidence for the rescheduled alert, then complete revision 1 to
revision 2. Preserve all earlier receipts and consumed fixture evidence. Reject
missing checkpoints, repeated/out-of-order actions, stale revisions, wrong
databases, and changed recipient/owner/times rather than guessing or resetting.

Backend domain/SQL checks establish persisted state and authorization, not native
notification scheduling, replacement, cancellation, or delivery. Those outcomes
must be observed by the native session at the corresponding checkpoint.

## Ready initial state

Prepared and independently reread from `legion_buddy_authority_test`. No later
checkpoint has run. The earlier authority handoff's initial-state tables are
historical; the consumed evidence is preserved in the baseline below.

| Field | Value |
| --- | --- |
| Synthetic recipient | Quinn Reminder, person `9` |
| Owner | Jamie Caller, user `1` |
| Organization | `1`, existing synthetic authority installation |
| Independent follow-up | `1`; `contact_id: null` |
| Initial status / revision | `open` / `0` |
| Entry zone | `America/Chicago` |
| Initial due time | `2026-10-13T15:00:00-05:00` / `2026-10-13T20:00:00Z` |
| Proposed rescheduled time | `2026-10-13T16:00:00-05:00` / `2026-10-13T21:00:00Z` |
| Accepted scheduling receipt | Buddy operation row `5` |
| Scheduling operation UUID | `fe606a3c-017f-46e9-a892-acf1e77987da` |
| Reserved reschedule UUID | `16ec4ae0-44cb-4c4a-b43f-78a50bd04618` (no receipt yet) |
| Reserved completion UUID | `3203e8f7-e42b-4f4c-b71e-7c41c7e1aea8` (no receipt yet) |

These UUIDs are backend fixture operation identities, not credentials or IDs for a
new mobile submission. Quinn has no contact, assignment, attendance row or address
review. Jamie can read the follow-up; Riley cannot. A future open follow-up excludes
Quinn from new suggestions under the existing policy. Use the follow-up list to
test the native reminder, not a suggestion.

The backend created the follow-up through `BuddyChecks::Operations.schedule` as
Jamie. This verifies domain persistence; it is not a native or HTTPS scheduling
claim. The accepted scheduling receipt has an independent `follow_up` and no
`contact` key. There are still exactly six earlier contacts.

## Existing connection and sign-in

Reuse these verified public settings:

| Setting | Value |
| --- | --- |
| Issuer | `https://192.168.37.41:3444` |
| Public client ID | `Ocja_43C84cZXkPbrdZS26r8cmV_5h8ydCkSEYhFIik` |
| Callback | `org.wipost165.buddychecks:/oauth/callback` |
| Scope | `buddy_check` |
| Client / PKCE | Public, no secret; S256 |
| Jamie sign-in | `jamie@example.test`, existing ephemeral browser email/code flow |
| Private synthetic inbox | `/tmp/legion-buddy-authority/mail/1.json` |
| Follow-up list | `GET /api/mobile/v1/buddy-checks/follow-ups` under Jamie's current human credential |

Read the inbox only after requesting a new code in that same browser. Do not put
codes, sign-in links or credentials in shared evidence. Prior native token `8` is
revoked; the native session signs in normally.

The existing public CA is
`/home/andre/Development/LegionPostTools/tmp/buddy-authority-public/buddy-authority-test-ca.cer`
(also `.pem`), with SHA-256 fingerprint:

```text
49:20:25:9F:8B:67:B8:E3:7A:EC:51:34:45:52:40:24:45:41:0C:58:37:44:76:7B:5F:E9:F5:E3:04:29:EC:97
```

It expires October 19, 2026 at 11:42:30 UTC. Use the approved disposable simulator
trust scope from the [authority handoff](MOBILE_BUDDY_CHECK_AUTHORITY_ACCEPTANCE.md).
No CA, issuer, client, callback, server configuration or trust-store change was
made here. Both port `3444` and original port `3443` returned HTTPS health 200 with
TLS verification result 0. Their existing environment, fixture, TLS material and
PID files have unchanged SHA-256 fingerprints; neither process was restarted.

## Backend checkpoints: do not run in advance

Run from `/home/andre/Development/LegionPostTools`. Replace the quoted placeholder
with the actual native run ID, checkpoint time and observed behavior. No timer or
automatic transition is armed.

After the native app confirms a real scheduled alert for follow-up `1`:

```sh
ruby test/manual/buddy_authority.rb reminder advance reminder_reschedule 'ACTUAL NATIVE RUN, TIME, AND SCHEDULED-ALERT OBSERVATION'
```

Expected: same follow-up/person/owner/contact association, still `open`, revision
`1`, due `2026-10-13T21:00:00Z`. The reschedule uses the reserved UUID and normal
`BuddyChecks::Operations.change_follow_up` workflow. Scheduling receipt `5` and
all prior receipts remain unchanged; one new receipt is added. No contact is added.

Only after native refresh and restart confirm the rescheduled alert:

```sh
ruby test/manual/buddy_authority.rb reminder advance reminder_complete 'ACTUAL NATIVE RUN, TIME, AND RESCHEDULED-ALERT REFRESH/RESTART OBSERVATION'
```

Expected: same follow-up, revision `2`, status `completed`, rescheduled due time
retained. One completion receipt is added; prior receipts remain unchanged.
Completion does not record a Buddy Check. Native cancellation/removal of the
scheduled alert must be observed separately.

Read current state without advancing anything:

```sh
ruby test/manual/buddy_authority.rb reminder status
```

The private plan `/tmp/legion-buddy-authority/reminder.json` holds fixed times and
the three operation UUIDs. The helper shares the existing backend control lock;
its separate append-only `reminder-checkpoints.jsonl` journal records observations.
It refuses repeated setup and unexpected state. After an interruption, inspect
status and the original operation receipts; do not delete the plan, regenerate
UUIDs, or reset evidence. If the proposed due time has passed, report drift before
changing the plan. The helper intentionally has no reset/reopen command.

## Preserved evidence and baseline fingerprints

Read-only whole-row fingerprints were captured for all 72 public tables in each
synthetic database. All earlier rows matched after preparation. Only authority
person `9`, independent follow-up `1`, and scheduling receipt `5` were appended.
The entire original `legion_buddy_mobile_test` database matched its prior counts
and fingerprints, including its client registration. Authority client registration
also matched. No contact, position, assignment, attendance or address-review row
was changed.

The following are full-table fingerprints, using
`md5(coalesce(string_agg(row_to_json(t)::text,E'\n' ORDER BY id),''))`.

| Table | Count before → after | MD5 before | MD5 after |
| --- | --- | --- | --- |
| `people` | 8 → 9 | `97b9b5de29d5264dd05f04d8ec6f480b` | `704cd6d6c6068e093e299521d455b47e` |
| `buddy_follow_ups` | 0 → 1 | `d41d8cd98f00b204e9800998ecf8427e` | `4fc800cf5a1208df708bbc6f2773cadb` |
| `buddy_operations` | 4 → 5 | `27bb9e234b356c068a29e4cef807f6c1` | `f73420a583267b42bdc2374a5da5bf62` |

For these tables, count and fingerprint are identical before and after:

| Table | Count | MD5 |
| --- | --- | --- |
| `membership_contacts` | 6 | `decceca60bd1dc55b130df24c17de521` |
| `membership_assignments` | 3 | `7d17bc8ee7a052a27d36953f23543011` |
| `buddy_attendance_registers` | 6 | `b658930bd250f36d49e9c2c78dfbc515` |
| `buddy_address_reviews` | 1 | `05e67d43d1df92a2025caee88ea88f9b` |
| `position_assignments` | 3 | `2f8cbb2324bb16d02012ddd3d377c5f0` |
| `buddy_snoozes` | 0 | `d41d8cd98f00b204e9800998ecf8427e` |
| `oauth_applications` | 1 | `dd534671b2939bc9015d0a0f7ca2cdad` |

Private aggregate evidence is retained in
`/tmp/legion-buddy-authority/reminder-before.json` and `reminder-after.json`.
The original four operation receipts and eight people were also fingerprinted
separately after the append and matched exactly. Neither future checkpoint has a
receipt yet.

## Verification and changed paths

- Existing domain/API regression command, isolated ordinary test database:
  `env -u DATABASE_URL -u BUDDY_MOBILE_INTEGRATION -u BUDDY_MOBILE_FIXTURE_FILE RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/api/mobile/buddy_checks_test.rb`
  passed **11 tests, 102 assertions, zero failures/errors/skips**, seed `11118`.
  This includes follow-up reschedule, stale-revision denial, completion, owner
  filtering and no extra contact. It does not establish native reminder behavior.
- New helper preparation/state checks passed **12 assertions**: repeated setup and
  missing-checkpoint rejection; initial identity/time/revision; distinct future
  reschedule; accepted scheduling receipt; no future receipts; caller ownership;
  Quinn accessibility; no new contact; prior native token revocation; public client.
- The exact-database guard rejected the ordinary test database before fixture
  access. Its first ad hoc runner command used an incorrect relative require;
  the corrected absolute Rails-root require passed. No fixture mutation occurred
  in that failed command.
- Three Ruby syntax checks and focused RuboCop passed (3 files, no offenses).
  Diff whitespace checks passed. Future helper transitions are deliberately not
  pre-executed against the live fixture; their native checkpoints remain pending.

Only these repository paths changed for reminder preparation:

- `test/manual/buddy_authority.rb` — routes the guarded reminder subcommands.
- `test/manual/buddy_reminder_fixture.rb` — isolated setup/status/checkpoint control.
- `test/manual/buddy_reminder_control.rb` — runner entry point.
- `docs/MOBILE_BUDDY_CHECK_REMINDER_ACCEPTANCE.md` — this handoff.

No application behavior, API, schema, production, commit, push, deployment,
service restart, database reset, or cleanup was performed.
