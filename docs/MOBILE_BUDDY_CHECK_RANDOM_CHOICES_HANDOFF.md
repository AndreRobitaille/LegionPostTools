# Random Buddy Check choices and production clock investigation

> Release procedure update (November 1, 2026): commands below describe the dated
> handoff/release. For any new release use the [current deployment playbook](DEPLOYMENT.md):
> successful isolated image build, explicitly authorized publication, and a verified
> digest inside one owned `bin/release session`. The old push-deploy/keep-master
> commands are superseded. Activation still requires its own explicit authority.


October 12, 2026. Implementation based on
`0e8fbd294cae75b62f5c503106efe5b55ecee9b7`. Andre approved the scoped backend
release, then separately requested NTP repair after deployment. This document
records the implementation and pre-release evidence; deployment and clock-repair
results must be reported from the completed operations.

## Additive public contract

`GET /api/mobile/v1/buddy-checks/suggestion` preserves the existing state and
coverage contract. An `insufficient_history` response adds `random_candidates`,
containing one to three distinct `{id, first_name, last_name}` objects drawn from
the existing permitted and eligible suggestion population. All caller exclusions,
self exclusion, personal snoozes, roster removal/deceased rules, current assignment
authority/coordination, pauses, recency and open-follow-up exclusions still apply.
An exhausted pool has no choices; ranked candidates keep their existing response
and evidence priority and omit this field. No phone, email, roster facts or other
caller's notes are included.

Sampling supplies choices without inventing contact history or an evidence reason.
Repeated requests may differ. Reads create no contact, follow-up, snooze, assignment
or receipt. Existing clients can ignore the additive field. The new native client
must tolerate omission, validate the three-person bound/identities/exclusions and
fetch a fresh preparation card before contact. No migration, new scope, grant,
issuer, callback, client, expiry, CSRF or eligibility change is involved. See the
[API handoff](MOBILE_BUDDY_CHECK_API_HANDOFF.md) for the complete JSON example.

Only the backend response and synthetic tests/documentation changed. Swift UI,
device/server clock comparison and stale-button handling remain mobile work. No
real call was placed or authorized as a diagnostic.

## Verification

The new unknown-history test failed against the original implementation because
`random_candidates` was absent (1 test, 2 assertions, 1 expected error). This
establishes detection of the missing contract field.

Focused synthetic command in the ordinary test database:

```sh
env -u DATABASE_URL -u BUDDY_MOBILE_INTEGRATION -u BUDDY_MOBILE_FIXTURE_FILE \
  RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/services/buddy_checks test/controllers/api/mobile \
  test/controllers/mobile_authentication_test.rb test/controllers/buddy_evidence_review_test.rb
```

Result: **47 tests, 454 assertions, zero failures/errors/skips**, seed `53428`.
New service coverage uses seeded random sources for repeatable bounded/distinct
samples and different deterministic samples. It checks identity-only output,
unknown history, small/exhausted/self-only pools, live directory/assignment access,
removed/deceased recipients, personal hiding/cancellation/expiry, other callers,
pauses, assignment coordination, attempts/conversations, own/other future/due
follow-ups and legacy date callbacks. Existing ranked history and attendance
responses retain priority. Service row snapshots and API count checks establish
no writes. The HTTP integration test checks actual serialization and exclusions.

The first expanded run stopped on a test fixture's omitted administrative-review
note (32 tests, 284 assertions, 1 error); adding the required synthetic note fixed
the setup. The passing command above includes that case. This was not an
application behavior failure.

Focused RuboCop: 3 files, no offenses. Brakeman 8.1.0 completed with zero security
warnings and zero errors (`GEM_SPEC_CACHE=/tmp/buddy-random-gem-spec-cache
bin/brakeman --no-pager -q`). Diff/new-file whitespace and local handoff links
passed. No native UI test was performed for this backend change. Existing consumed
synthetic fixtures were not reset or used for these tests. In the isolated release
checkout, the full ordinary suite passed with **1,432 tests, 14,193 assertions,
zero failures/errors/skips**, seed `60007`. Full RuboCop inspected 604 files with
no offenses; Brakeman again found zero warnings/errors; Bundler Audit found no
vulnerabilities. The repository release transport preflight passed.
The separately run full browser suite passed with **93 tests, 5,387 assertions,
zero failures/errors/skips**, seed `4269`.

## Production clock evidence

The production host's system clock is approximately **83 seconds slow** relative
to this workstation, the independent Codex UTC clock and responding NTP sources.
The reported Mac observation agrees; the backend did not remotely inspect the Mac
or physical phone clock settings.

- At local `2026-10-12T17:53:22.635Z`, verified HTTPS `/up` returned 200 with
  `Date: Mon, 12 Oct 2026 17:51:59 GMT` (about -83.635 seconds; 0.117-second RTT).
  Anonymous `/api/mobile/v1/session` returned the expected 401 with the same Date
  (about -83.774 seconds; 0.161-second RTT). Both used unique query strings and
  neither had an Age header.
- The host reported `17:52:35 UTC` while its RTC reported `17:53:58 UTC`.
  `NTP=yes`, but `NTPSynchronized=no`; the enabled, active service is
  `systemd-timesyncd`, with packet count 0 and repeated UDP/123 reply timeouts.
  Chrony/ntpd are not installed as active services. The drop-in
  `/etc/systemd/timesyncd.conf.d/hetzner.conf` sets `NTP=ntp.hetzner.com`.
- A read-only production Rails runner reported `Time.current` as
  `2026-10-12T12:52:39.293051-05:00`, `Time.now.utc` as
  `2026-10-12T17:52:39.293172Z`, and realtime epoch `1791827559.2931757`.
  Thruster on container port 80 returned Date `17:52:39 GMT` while container time
  was `17:52:39.556Z`. Direct Puma port 3000 returned 200 without a Date header.
  Host time immediately afterward was `17:52:39.571Z`. Thus the frontend HTTP Date
  and Rails `Time.current` agree with the same slow host realtime clock; the
  discrepancy is not a Rails zone conversion or stale public response.
- One read-only NTP query per source from production timed out for
  `ntp.hetzner.com` (`213.239.239.166`) and `ntp.ubuntu.com` (`91.189.91.157`).
  From this workstation, the same Hetzner IP replied at stratum 2 with an offset
  of -0.001688 seconds and RTT 0.122936 seconds. Ubuntu's resolved source
  `185.125.190.56` also replied at stratum 2, offset -0.001510 seconds.
- UFW was inactive; IPv4/IPv6 INPUT and OUTPUT policies were ACCEPT. The inspected
  raw rules protect container and local database addresses, and the mangle chains
  were permissive. `systemd-timesyncd` had no private network or IP allow/deny
  restrictions. The exact blocking layer in the production NTP network path is
  **not established**. Provider firewall/routing policy has not been inspected.

Restore working NTP request/reply connectivity for the shared VPS, then allow the
existing time service to synchronize and verify offset and `NTPSynchronized=yes`.
Changing application expiry, CSRF, or eligibility would not repair this host issue.
No firewall rule, NTP source substitution, manual clock step, service restart or
host configuration change was made during this initial diagnosis. Andre has since
authorized repair after the application deployment; its outcome is separate from
the pre-release observations above. Hetzner documents its available
[NTP sources](https://docs.hetzner.com/robot/dedicated-server/security/ntp-servers/).

All production SSH reads used one documented persistent control master. It was
closed and absence verified afterward; no fallback connection/retry occurred.
No production member rows, credentials or tokens were copied or queried.

## Release authorization and baseline

The live Post 165 web container was verified as:

```text
legion_post_165_wi_tools-web-54eb03d7f963ac1ec4a250ebbe390303dda77d70
```

**Pre-release revision: `54eb03d7f963ac1ec4a250ebbe390303dda77d70`.**
It does not include this additive change. No claim of a new deployed revision or
production random-choice behavior is made.

[AGENTS.md](../AGENTS.md) says, “Deploy only when Andre explicitly asks.” Andre's
approval covers committing only the six files below in a clean isolated checkout
and running the repository `bin/release check` and `bin/release push-deploy`
lifecycle. The release branch is `codex/buddy-random-candidates-release` in
`/tmp/legion-buddy-random-release`.
Preserve the unrelated untracked `docs/BUDDY_CHECK_MOBILE_APP_HANDOFF.md`; do not
stage, remove or stash it to satisfy the clean-worktree guard. No activation-email
option or grant/client re-registration is required for this additive release.

Scoped paths:

- `app/services/buddy_checks/suggestions.rb`
- `test/services/buddy_checks/suggestions_test.rb`
- `test/controllers/api/mobile/buddy_checks_test.rb`
- `docs/MOBILE_BUDDY_CHECK_DESIGN.md`
- `docs/MOBILE_BUDDY_CHECK_API_HANDOFF.md`
- `docs/MOBILE_BUDDY_CHECK_RANDOM_CHOICES_HANDOFF.md`
