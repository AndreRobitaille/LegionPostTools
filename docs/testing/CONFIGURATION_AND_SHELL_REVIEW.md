# Configuration, entry shell and receipt cleanup review

Bounded #84/#96 review, October 10, 2026, starting at `0a5686a`. Source review and
runner execution are separate evidence. Retain all existing tests and assertions;
no deletion, consolidation, UI change or application behavior change is proposed.

## Reviewed contracts

- `DatabaseConfigurationTest`: real ERB/YAML parsing proves safe nonproduction and
  asset-build defaults. The production refusal only tests missing `POSTGRES_DB`;
  the configuration also requires host, cache and queue names. Strengthen that
  existing refusal test with complete synthetic inputs and independently omit each
  required key. Clear the dummy-build flag explicitly so inherited environment cannot
  bypass the expected refusal. Add a positive fully supplied production parse to prove
  configured names/host remain in effect. Parsing does not boot or connect production.
- `FilterParameterLoggingTest`: actual configured ParameterFilter redacts the whole
  nested transcript and both un-nested content names. Its different input shapes have
  unique value; keep both, rather than replacing them with a source-array assertion.
- `TimeZoneConfigurationTest`: three real child-process test boots check default UTC,
  configured installation zone and useful invalid-zone refusal. Preserve process status
  and actual zone/error assertions; no stub would establish boot behavior. This does
  not resolve #93's separate Post-date authority policy.
- `AssetsTest`: pipeline resolution checks the Legion emblem; print CSS checks title-only
  item pagination separately from browser/PDF content selection. Keep both component
  contracts. The CSS assertions establish source rules, not visual printed-page proof.
- `CleanupAgentApiExecutionsJobTest`: real job execution deletes the 31-day row and keeps
  the 29-day row with its historical request path. Inspecting both persisted outcomes
  catches an overbroad deletion. It does not yet prove the exact cutoff or recurrence.
  Freeze time and retain an exactly-thirty-day row to prove the strict cutoff without
  weakening the old retained/deleted assertions. Current cleanup scope uses
  `created_at < 30.days.ago`; retain historical `/api/tracked_items`
  as audit fact rather than rewriting it to today's route name.
- `LoginPageTest`: rendered identity/emblem, actual form destinations, email/passkey
  controls, notice, magic-link confirmation and installation-free fallback are distinct.
  These request selectors do not prove actual sign-in; retain existing browser coverage.
- `PrimaryNavTest`: member/officer/admin destinations, current-section marking, menu
  identity and sign-out form routing all have different failure detection. Keep every
  assertion. The account-menu browser suite separately proves open/close, keyboard focus,
  phone destinations and real sign-out with pending/completed confirmation lineage.

## Verification plan

Run the focused existing component/request files in a disposable owned test database.
Temporarily bypass only the queue-name requirement in configuration; the strengthened
production refusal must fail specifically for that key, while old missing-primary coverage
would still pass. Restore exact configuration bytes in finally and rerun clean checks.
Separately make the cleanup comparison inclusive: the real job must fail the boundary
record preservation assertion. Restore exact model bytes and rerun clean checks.
No deployed configuration, real database or production connection is involved.

Before merge, record focused results/restoration, review intended changes, and require
final committed ordinary/system suites serially, lint/security, exact-SHA and actual-main
CI. Inventory/variant matrix updates must describe these bounded contracts; all other
files remain deferred under #84 until their independent review is completed.

## Focused evidence

The first request slice lacked built Tailwind assets in this new worktree: 29 tests,
44 assertions, 17 asset errors. Build the repository's existing test assets; do not
change assertions. Corrected run: 29 / 135 / 0 (seed 34606, 4.15s).

Bypassing only the queue-name requirement fails the strengthened original production
refusal after primary/cache scenarios passed: 1 / 7 / one failure (0.46s). Exact config
SHA-256 restored: `6e4341b3e21c20f3f148d38ea8a0bc9cf920f50913d31216092cb074db8faa57`.
Making cleanup inclusive deletes the boundary row and fails its persisted-preservation
assertion: 1 / 4 / one failure (seed 39995, 0.55s). Exact model SHA-256 restored:
`fd2343e00bb6744acbf9f1ad0adb11212d4105dd908d8d90f1749ec9dbdd1ccc`.

Restored focused configuration/filter/zone/asset/job/entry/navigation set:
29 / 135 / 0 (seed 43826, 4.88s). Both changed Ruby files lint clean; no application
fault remains. Existing parsing, process-boot, content-redaction, shell controls and
old/new receipt assertions remain. One positive production-input case and one exact
cutoff variant improve distinct detection; no removal or consolidation is justified.

The initial local design/test draft preceded the #96 tracking issue; that sequencing
exception is recorded in the issue and progress update. Final committed suites/CI and
bounded inventory/matrix entries remain required before completion.
