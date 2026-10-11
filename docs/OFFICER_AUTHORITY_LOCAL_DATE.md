# Post-local officer authority

Approved decision for #78/#93, October 11, 2026: Andre chose the Post's saved local
date for all dated officer duties and current role labels. Inclusive start/end dates,
explicit manual grants and last-administrator protections remain the governing policy.

## Implementation contract

One Organization date accessor resolves the current instant in the installed Post's
saved time zone. User position capabilities, full membership access, private agenda
notes, calendar management, Person current-role labels and the officer API use it by
default. Explicit dates remain supported for historical snapshots and component checks.
Before setup, or with an invalid legacy saved zone, use the configured application zone,
independent of a request's temporary time-zone context. Do not cache today's date across
requests or across midnight. This installation is one Post; no new tenancy is introduced.
The existing End role control also submits the Post-local date, so a near-midnight
administrator action cannot extend or shorten a term using another clock.

Role authority must agree through dashboard/calendar contexts and minutes/API contexts.
A previously issued token and human session gain duties on the start date and lose them
after the inclusive end date, without permanent per-user grants. A renamed office keeps
its configured duties. A manual drafting exception survives expiry without preserving
membership, private-copy or official-act authority. Historical agenda roll calls continue
to use their meeting date rather than the current date.

## Evidence before implementation

Extend the existing real-request turnover tests with fixed UTC instants straddling local
midnight in America/Chicago and Asia/Tokyo, independently specified local dates, future
starts and inclusive ends for both Commander and Adjutant. Reuse their real HTML/API
draft mutations and saved-record denial checks. Assert officer API rows/as-of, dashboard
navigation/menu labels, full membership and actual calendar mutation outcomes. Verify
official acts with the same token on the last active date and refuse them after expiry.
Use independent dates, not the new accessor, to compute expected results.

Retain every existing test. Reproduce the context disagreement on unchanged source,
then restore equal permitted/denied outcomes. Preserve explicit-date behavior and test
request-zone independence and both fallback states. No source or approval data changes.

## Visual direction and final verification

Apply the frontend-design skill with the established 1919 bounded navy/gold/cream shell,
system sans working text and existing officer tools/member navigation. The visible change
is consistent role/navigation truth at midnight; no new visual treatment is needed.
Inspect a real same-session save before local midnight, refused save afterward, current
role/menu disappearance and later member reading at 1400px and 390px. Keep body/controls
at least 16px, secondary text 14px and labels 13px. Review rendered overflow and menu state.

Run focused role/authority/calendar/handbook checks, then final-candidate full ordinary
and system suites serially, lint/security, exact-SHA CI and actual-main CI. Preserve
unrelated root work. No production, paid AI, real member data or deployment is authorized.

## Focused evidence

Source base `0fb2b678c1b7c3847ba92a09b09f3c1bca420aae`; local Ruby4.0.7,
PostgreSQL18.6, locked Rails8.1.4/gems and Chromium152. Disposable database
`legion_post_local_officer_test`; the shared `/tmp/legion-overnight-env` wrapper is used
with that explicit database override. No other database was reset.

- Before application edits, `bin/rails test test/integration/officer_turnover_authority_test.rb -i /midnight/`
  gives4/54/4 failures (seed13878): both Chicago future officers actually mutate saved
  minutes, both Tokyo newly active officers receive403. Earlier missing-assets and nil
  assertion harness failures are retained separately; neither is credited as a product
  failure. Assets were precompiled and the harness corrected before this reproduction.
- Restoring the old date in only Person's role methods fails all four independent role
  expectations:4/104/4 (seed41500). Intended bytes restored exactly,
  SHA256 `8cb0f49ddf6ee4f26a2f0f863f9e5b88f60cd292e8530c9d8919aa0d28af7a52`.
- Restoring only officer API's old date fails all four independent as-of assertions:
  4/116/4 (seed3453). Intended bytes restored exactly,
  SHA256 `9c21ce7f5c97bfbe6d8636e7205410e75859de4c94c94ac9c318453cd020522d`.
- Before the End role form edit, its two real rendered-form cases fail on the submitted
  date:2/4/2 (seed58293); one initial Nokogiri accessor harness error was corrected first.
  Both then submit that actual hidden field through the controller, preserve inclusive
  expiry and check the saved date. No expected date comes from the new accessor.
- Restored neighboring17 ordinary files pass190/2556, zero failures/errors/skips,
  seed21216,24.29s. These include the original turnover matrices, explicit historical
  dates, manual exceptions, last-administrator/confirmation, handbook, directory,
  position CRUD and real calendar writes. Short-day DST and fallback checks also pass.
- The strengthened original approval-flow browser case passes1/30 (seed4303,6.10s):
  real sign-in, same-session saves/expiry/refusal, member reading, sign-out and later
  protected denial. All original assertions remain. The new real End role browser case
  passes1/15 (seed49000,4.19s), on Chicago/1400 and Tokyo/390, with the affected role
  dates framed in the screenshots. Six desktop/narrow images are inspected.
- Focused RuboCop9 files and diff checks pass. The rendered menu/role/denial treatment
  remains bounded, readable and free of horizontal overflow. Initial wrong navigation
  multiplicity and uppercase browser-text expectations were corrected, not credited as
  product regressions. No test was removed, skipped or given permanent broader grants.

PR #144 candidate `c1b748f3d78282cfd672bc49ed4a0f4ed3693bc4` merged normally as
`860373344afc002d66f43ab17f83958a10be85b9`, with an identical tree. Committed local
ordinary 1316/12758 then system 77/1811, zero failures/errors/skips; full lint/security
passed. Exact candidate CI38135025374 and actual-main CI38135710941 pass all four
jobs and the same serial suite totals. #78 and #93 closed after actual-main verification.
