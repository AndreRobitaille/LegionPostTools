# Workflow regression review — October 10, 2026

Persistent goal: GitHub issues #77–#84. Source baseline:
`5adda175d67e9603f58fdf8574ad6f7a0313d6b9` (`main`). Work isolated in
`codex/workflow-regression-review`, `/tmp/legion-overnight`; original worktree untouched.
Discovery documents copied from the authorized local artifacts; claims in them remain
source discovery, not runtime evidence.

## Environment and boundaries

Ruby 4.0.7, Bundler 4.0.20, PostgreSQL 18.6, Chromium/ChromeDriver 152.0.7977.82.
Missing repository-locked gems were installed into `/tmp/legion-overnight-bundle`;
no dependency upgrade. Synthetic checks use `RAILS_ENV=test`,
`DATABASE_URL=postgresql:///legion_overnight_test`, `PARALLEL_WORKERS=2`.
Environment wrapper: `/tmp/legion-overnight-env`; exact commands below use it.
No development database setup/reset, member-data copy, production operation or paid AI.

GitHub inspection: only CI and Dependabot workflows active; CI runs scans, lint, ordinary
and then system tests, with no deploy step. No repository webhooks or rulesets, main
branch protection endpoint reports unprotected. Local hooks have no deploy action.
Push/merge does not invoke repository deployment. Recheck before first push/merge.

## Baseline

- Initial `bundle check`: failed, missing locked gems (including pg 1.7.0, Lexxy 1.0.1,
  OpenAI 0.103.0 and Selenium 4.51.0).
- `source /tmp/legion-overnight-env && bin/rails db:test:prepare && bin/rails test`: passed; seed 2911, 1190 runs, 8881 assertions, 0 failures/errors/skips, 92.63s.
- `source /tmp/legion-overnight-env && bin/rails test:system`: passed after ordinary; seed 34982, 64 runs, 1014 assertions, 0 failures/errors/skips, 84.38s. The wrapper overrode the base single-browser setting to 2 workers. Final system verification will explicitly use `PARALLEL_WORKERS=1`.
- RuboCop: 489 files, 0 offenses. Brakeman: 0 errors, 0 security warnings. First attempt hit read-only RubyGems cache; succeeded with `GEM_SPEC_CACHE=/tmp/legion-gem-spec-cache`. Gem audit: no vulnerabilities, advisory DB `a6847b0651a702488f5844081e848dd1ec9dbf1d`; used `check --update --database /tmp/legion-advisory-db --config config/bundler-audit.yml`. Importmap audit: no vulnerable packages.
- No skip calls located by `rg -n \bskip\b test`; runtime suites reported 0 skips. Rails boot and browser/PDF dependencies available.

## Issue ledger

| Issue | Contract and review unit | Current status |
| --- | --- | --- |
| #77 | Member Meeting and immutable document reads, personal token parity and handbook | Current issue read; policy/source investigation pending |
| #78 | Independent Commander/Adjutant duties through assignment transitions | Current issue read; policy/source investigation pending |
| #79 | 30-day recovery after final approval; source removal and retained record/audit | Current issue read; policy/source investigation pending |
| #80 | Final occurrence context protected independently from agenda state | Current issue read; policy/source investigation pending |
| #81 | Current handbook, delegated official acts and Post website credential boundaries | Current issue read; policy/source investigation pending |
| #82 | Referenced Meeting Type delete refusal and later document reads | Complete: PR #85 merged; candidate and actual main CI successful |
| #83 | Referenced agenda/child delete refusal without historical loss | Complete: PR #85 merged, including AI lineage; candidate and actual main CI successful |
| #84 | All-file inventory, workflow variants, assertions and demonstrated detection | Initial file inventory; remaining review explicitly deferred to slices |

No acceptance criterion is completed by this initial inventory. No test removed,
consolidated or weakened. Discovery documentation committed as `002f41e`. No push, PR or merge yet; controlled-fault evidence is recorded below.

## Runner review

`.github/workflows/ci.yml`: push to main and pull request; ordinary suite then system
suite in the same test job. `config/ci.rb`: ordinary then system; also seed check.
Do not run `bin/ci` wholesale here: its setup step prepares development data.
`test/test_helper.rb`: ordinary tests parallel with explicit worker limit; all fixtures;
cache reset; integration authentication directly creates a Session and cookie.
`test/application_system_test_case.rb`: single browser, server on 0.0.0.0, real magic-link
GET then confirmation POST; binary paths pinned. Login setup is not sign-in coverage.
All `*_test.rb` files inventoried separately; detailed assertion review remains open.

## #82/#83 — reproduced restrictions, first repair

Design: `docs/PROTECTED_MEETING_CONTENT_DELETION.md`, written before controller changes.
Existing successful-delete and component tests retained. New cross-interface integration
matrix exercises type, agenda, item, empty section and routed agenda/item API deletes with
draft, attested and final minutes, plus late references, rollback and AI source lineage.
No section-delete API is currently routed; no endpoint invented for this review.

- Original regression command: `bin/rails test test/integration/protected_meeting_deletion_test.rb`
  with wrapper; seed 32760: 22 runs,
  21 assertions, 0 failures, **21 errors**, 0 skips. Expected unhandled
  `DeleteRestrictionError` on actual HTML/API routes. AI-only suggestion lineage also
  reproduced `InvalidForeignKey` because the model lacked the reverse restriction.
- Repair handles only expected restriction/destruction failures and retains source
  dependencies; adds reverse `minutes_draft_suggestions` restriction, avoiding raw FK error.
- Focused command: `bin/rails test test/integration/protected_meeting_deletion_test.rb
  test/controllers/admin/meeting_types_controller_test.rb
  test/controllers/admin/dated_agendas_controller_test.rb
  test/controllers/admin/dated_agenda_items_controller_test.rb
  test/controllers/admin/dated_agenda_sections_controller_test.rb
  test/controllers/api/agenda_parity_api_test.rb`: seed 36385; 115 runs,
  887 assertions, 0 failures/errors/skips, 15.07s.
- Browser/doc test strengthened with real refused-delete controls at 1400px/390px
  before existing ordinary-member document reading; real PDF bytes extracted with
  pdftotext after refusal. Verification pending.
- Controlled source-detachment fault planned in `/tmp/legion-protected-fault-plan.txt`;
  exact-byte restoration and a clean rerun are required. Fault completed and restored; see below.

- Expanded fixture includes a real template/catalog copy, roll-call lineage, minutes
  outcomes/attendance and immutable attestation metadata. Added foreign-Post delete
  denials. Expanded matrix: `bin/rails test test/integration/protected_meeting_deletion_test.rb`,
  seed 22504; 23 runs, 331 assertions, 0 failures/errors/skips, 7.63s.
- Browser: `PARALLEL_WORKERS=1 SYSTEM_TEST_CAPTURE_DIR=/tmp/legion-protected-screenshots
  bin/rails test test/system/meeting_documents_test.rb`, seed 25898; 2 runs, 127
  assertions, 0 failures/errors/skips, 19.22s. Type native confirmation and agenda
  dialog at 1400px/390px; alerts, surviving records/digests; subsequent ordinary-member
  HTML and real agenda/minutes PDF text include saved heading/business/authority and
  exclude private cues/renamed template. Desktop/narrow screenshots inspected:
  readable 16px alert, wrapping without overflow, navigation and document actions usable.
- Initial PDF extraction helper needed binary mode for Open3; corrected the test helper,
  not application behavior. A template-fixture draft also used a nonexistent local
  field; corrected to use the catalog's behavior before expanded validation. Both failed
  attempts are retained in this record, not counted as application regressions.
- Controlled fault: add `@item.minutes_items.update_all(source_dated_agenda_item_id: nil)`
  solely inside the HTML item's restriction rescue. Expected graph equality failure
  despite correct refusal/status. Named regex command matched the HTML and API draft
  item tests: seed 56150; 2 runs, 18 assertions, 1 failure (graph equality),
  0 errors/skips. Exact controller bytes restored in Python `finally`, verified by
  SHA-256 equality. Same clean command, seed 31559: 2 runs, 20 assertions, 0 failures/errors/skips.
  Logs: `/tmp/legion-protected-detachment-{fault,clean}.log`. No experimental fault remains.
- Focused RuboCop: nine changed Ruby files, no offenses. `git diff --check` passes.
- Discovery documentation: 1063 local link targets resolve, 62 unique workflow contracts,
  no missing controller/view/Stimulus/job paths in the source ledger. Historical map
  baseline is preserved; this review's runtime evidence is separate.

## #79 policy question

Current promise says 30 days after membership approval, but approved-with-pending-
corrections is recorded before final Adjutant attestation. Asked whether recovery begins
at the real meeting decision or the final corrected attestation. No dependent retention
implementation until this material choice is resolved; other issue work continues.
Application purge would not prove deletion from separately managed backups.

## Final-candidate preparation for #82/#83

Fresh review: current model/database restrictions are preserved; no source detachment,
permission expansion or official-state edits. Existing published-agenda removal without
references remains supported. Agenda deletion is refused because of real source references,
not merely because a Meeting also has independently-created minutes. Late screen references
are rechecked by destruction callbacks. Child parent-lock checks and optional template-item
nullification remain distinct. No section-delete API route was added.

Simplify pass: reused the seeded report object and extracted the paired browser-delete
assertions into `assert_protected_deletions` with explicit records; all existing UI,
provenance, formatting and member assertions remain. No test removed/consolidated/skipped.
Focused model/neighbor/request verification is recorded in `/tmp/legion-protected-final-focused.log`.
Final candidate ordinary/system suites will run serially after the code commit; results
and exact SHA will be attached to the PR and morning handoff, with CI separately verified.

Final neighboring model/request run: seed 35518; 149 runs, 1001 assertions, no failures/errors/skips (19.15s). Browser assertion extraction retained all 127 assertions; final focused browser seed and duration are recorded in `/tmp/legion-protected-final-browser.log`. Added a routed late-item-reference scenario after opening its editor; final focused result is in `/tmp/legion-protected-last-focused.log`. No source/test fault marker remains.

## #82/#83 merged verification

Final candidate `9d971a32d904f42d57a47257870cd194ce23469b`: full ordinary suite,
seed 63445, 1214 runs / 9220 assertions / 0 failures/errors/skips (95.09s), followed
serially by full system suite with `CI=true PARALLEL_WORKERS=1`: 64 runs / 1071
assertions / 0 failures/errors/skips (152.27s). RuboCop 490 files / 0 offenses;
Brakeman 0 errors/warnings; gem and importmap audits clean; diff check passed.
Exact candidate CI run 38102197566 passed all four jobs and actually ran both suites.

[PR #85](https://github.com/AndreRobitaille/LegionPostTools/pull/85) merged at
2026-10-11 01:39:24 UTC as `b092bf6789d7611d55747ebc1acdc5bf85b6b369`.
Actual main tree matches the tested candidate (`bdac19f698ea34ee672b199cd8b01701c0bcca36`);
main CI run 38102560190 passed all four jobs. #82/#83 closed by the merge, with
completion evidence posted. No release/deploy/production command ran.

## #84/#86 fresh-schema guard regression

[Issue #86](https://github.com/AndreRobitaille/LegionPostTools/issues/86) is a bounded
#84 follow-up, not a claim that the wider test review is complete. Before repair,
fresh Ruby-schema preparation omitted all eleven existing PostgreSQL triggers. New
component tests attempted direct update/delete of finalized minutes, revisions,
attestations, events and approvals. They require the actual guard's message, so an
incidental FK violation cannot be mistaken for immutable-record protection.

- Original Ruby-schema database: 12 runs / 19 assertions / 11 failures / 0 errors/skips.
  A migration-only test attempt also failed: Rails maintenance reloaded the Ruby schema
  and dropped the triggers. This is evidence about the real preparation path.
- Faithful SQL path from a blank owned synthetic database: focused guard tests,
  seed 43460, 12 runs / 45 assertions / 0 failures/errors/skips.
- A separately loaded fresh SQL database: seed 25219, same 12 / 45 / 0 result.
  Compared metadata for 679 columns, 731 constraints, 274 indexes, five functions,
  eleven triggers and 57 sequence definitions: identical between migration-built and
  freshly loaded schemas. Canonical metadata SHA-256:
  `f4af70931f2241e79711706bfb7952e375f769244e7e59af35a870582b9f9d84`.
- Exploratory full ordinary suite on that fresh SQL database: seed 31516,
  1226 runs / 9265 assertions / 0 failures/errors/skips (103.05s).
- No existing component/browser tests removed or relaxed. Trigger inventory proves
  preparation; only the exercised operations establish behavioral detection. Endeavor
  guard variants still need their own bounded review. No production guard claim.

Commands use the existing environment wrapper with
`DATABASE_URL=postgresql:///legion_guard_roundtrip_test`; ordinary and system suites
run serially. Final candidate verification and merge/CI evidence remain required.

An exploratory system run passed 64 / 1071 / 0, but a short focused component rerun
accidentally overlapped it. That system result is excluded from merge evidence. A new
serial focused run precedes the commit, and both full suites will run serially on the
committed candidate. YAML parses, RuboCop 491 files / 0 offenses, Brakeman 0 errors and
warnings. The SQL dump contains only schema definitions and migration version inserts,
not copied member rows. No experimental application fault or trigger installer remains.

Candidate `868df1801e73fdb1956d355ec07ec60b4ceebb7f` was pushed as draft PR #87.
CI run 38103140298 passed all scans/lint but failed before tests: Ubuntu apt could not
locate `postgresql-client-18`, despite the previous runner's preinstalled libpq 18.6.
Added PostgreSQL's official HTTPS key and signed distro-specific apt source to CI
package setup. This failing run cannot qualify a merge; the new revision requires
successful exact-SHA CI and serial local final suites. No CI bypass or dependency
upgrade was used to suppress the failure.

Corrected candidate `4f00780b351920ffd170350ff704690f9a644027`: CI run 38103260738
passed all four jobs, including actual 1226 / 9265 ordinary and 64 / 1071 system runs.
It installed client 18.6 from the official signed PostgreSQL source. Final local ordinary
seed 26558 passed 1226 / 9265 / 0 (99.26s), followed serially by system seed 16467:
64 / 1040 / **one failure** / 0 errors/skips (149.22s). This failure prevents merge.

## #84/#89 speculative form-response/session race

Existing `MinutesApprovalFlowTest` failed at the confirmation code form. Screenshot
showed invalid/expired official request. The log showed a heading GET returning after
the attestation confirmation page; next POST had the same authenticated Session but a
null pending confirmation ID. Bundled Turbo uses hover prefetch with X-Sec-Purpose.

[Issue #89](https://github.com/AndreRobitaille/LegionPostTools/issues/89) records the
bounded finding. Design is `docs/OFFICIAL_ACTION_PREFETCH.md`. A new real-browser
regression delays only the speculative heading response, starts the actual attestation,
then releases the old response before requesting email. Original default layout: 1 run /
8 assertions / 1 failure / 0 errors/skips (5.34s), at the same missing code form.
Its test-only callback is released and removed in teardown. No approval bypass occurs:
the old behavior refuses the missing request, leaving the minutes unpublished.

The fix disables link prefetch in the private application layout, preserving real click,
Turbo submission, identity, stale-record, permission and one-use checks. It does not
claim a general manual multi-tab CookieStore redesign. A new helper initially stopped
job execution before the asynchronous email request completed, producing a nil test
delivery; moved the code-form wait inside the job block. This was a test synchronization
error, not a second application bug. No expectations removed or skips introduced.

#88 independently scopes Endeavor SQL guards and legitimate run progress. #84 remains
open; component/browser runner success is separate from deferred variant review.

Final focused requests: official-action, passkey and session controller tests, 39 runs /
527 assertions / 0 failures/errors/skips (2.40s). Then serial browser confirmation,
minutes approval and account menu tests, seed 2233: 11 / 134 / 0 (23.11s). A controlled
fault removed only the new layout meta/comment bytes: 1 / 8 / one missing-code-form
failure (5.47s). Python `finally` restored exact layout bytes, verified by SHA-256;
same restored scenario passed 1 / 18 / 0 (4.82s). Logs are
`/tmp/legion-prefetch-{controlled-fault,restored-clean}.log`. The temporary delayed
response is released and its callback removed; no experimental application fault remains.
All 492 Ruby files pass RuboCop; Brakeman 0 errors/warnings, both dependency audits clean.
PR #87 will include the independently recorded #89 fix; final full serial suites and
new exact-SHA CI are required for the combined candidate. No test removed or weakened.
Inspected desktop and 390px confirmation screenshots: action/record identity and code
entry remain readable, wrapping correctly with ordinary vertical scrolling and no
horizontal overflow. Existing 1919 visual layout is unchanged.
