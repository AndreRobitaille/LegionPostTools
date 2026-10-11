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
| #77 | Member Meeting and immutable document reads, personal token parity and handbook | Complete: PR #91 merged; candidate and actual-main CI passed |
| #78 | Independent Commander/Adjutant duties through assignment transitions | PR #94 current-role/action/refusal proof and candidate/main CI passed; open pending material date-boundary decision #93 |
| #79 | 30-day recovery after final approval; source removal and retained record/audit | Draft PR #98 records retention/storage/provenance design; awaiting start-of-recovery choice; no purge runtime implemented |
| #80 | Final occurrence context protected independently from agenda state | Complete: PR #90 merged; candidate and actual-main CI passed |
| #81 | Current handbook, delegated official acts and Post website credential boundaries | Complete: PR #97 merged; independent handbook/actions and candidate/actual-main CI passed |
| #82 | Referenced Meeting Type delete refusal and later document reads | Complete: PR #85 merged; candidate and actual main CI successful |
| #83 | Referenced agenda/child delete refusal without historical loss | Complete: PR #85 merged, including AI lineage; candidate and actual main CI successful |
| #84 | All-file inventory, workflow variants, assertions and demonstrated detection | Open: bounded source/assertion/fault reviews merged; many remaining variants/files and linked findings remain |

The initial inventory alone completes no acceptance criterion. No test removed,
consolidated or weakened. Discovery documentation committed as `002f41e`; subsequent
scoped commits/PRs and controlled-fault evidence are recorded below.

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

Final source review found deployment and Cloud development specify PostgreSQL 17, while
the baseline floating CI service and this machine use 18.6. The Dockerfile already has
PostgreSQL client tools. Align the CI service/client with the repository's configured
major 17 to verify standard SQL-schema loading on that target; keep the local 18.6
verification separate. No deployment configuration, container or production data is
inspected/changed. This requires fresh candidate CI and final serial local verification.

PR #87 final candidate `c76627fd6b80897bb1ed2b3d4105498daf33d6ca`: local ordinary
1226 / 9265 / 0 (seed 11609, 100.76s), then system 65 / 1089 / 0 (160.89s).
All four candidate CI jobs in run 38104270364 passed; logs prove PostgreSQL server/client
17.11 and actual ordinary/system execution. Merged as
`34d6abd7128b771049589c80a7cf1d198f1b61bf`; tree matches the candidate. Actual main CI
38104592150 passed all four jobs, including serial ordinary/system steps. Issues #86/#89
are complete; #84/#88 remain open. No deployment, production inspection or paid AI.

## #80 Meeting context after final approval

Design: [Final Meeting context](../FINAL_MEETING_CONTEXT.md). Seven explicit historical
fields are protected independently of agenda status; website notice edits remain allowed.
Original `b092bf6` routed variants: 6 / 6 / six failures, each accepting title mutation.
Strengthened original persisted-graph assertion: 1 / 1 / one failure, proving occurrence
mutation while the signed minutes stayed unchanged. No production record was inspected.

New-worktree focused preparation first produced 13 missing-Tailwind errors. After
`bin/rails tailwindcss:build`, six focused files passed 46 / 560 / 0 (seed 41535, 6.21s):
`test/integration/final_meeting_context_test.rb`, `test/models/meeting_test.rb`,
`test/models/official_record_database_guards_test.rb`,
`test/controllers/admin/meetings_controller_test.rb`,
`test/controllers/api/meetings_api_test.rb`, `test/controllers/meeting_minutes_controller_test.rb`.
Database: owned `legion_context_race_test`, test environment, no source/AI mocks.

Manual two-connection actual-finalization race passed on PostgreSQL 18.6; see the design
for exact scope and observer correction. The SQL schema preserves all prior guards and
adds two functions/triggers. Standard pg_dump normalized some equivalent array casts.
The new browser argument to `test:system` did not select a file: Rails' rake task runs
the entire suite. Record that result as a full exploratory run and use `bin/rails test
test/system/minutes_approval_flow_test.rb` for focused capture. Final merge verification
is still pending; no tests removed, weakened or skipped.

Exploratory full system seed 29299: 65 / 1096 / 0 failures / one error (164.30s).
The added archive selector matched both original and later PEC rows; selecting the row
by its exact minutes URL removes ambiguity and explicitly asserts record identity.
No application failure or relaxed expectation. Focused direct file runner seed 9718
passed 2 / 104 / 0 (18.77s), including desktop/390px refusal, member archive and actual final
PDF text. Refusal screenshots inspected: readable wrapping/controls, no horizontal
overflow. RuboCop 495 files / zero offenses; Brakeman zero errors/warnings; gem and
importmap audits report no vulnerabilities. Full serial final revision checks remain.

#80 final candidate `2b7be1f06e8679800acf8500a1f702ba0041fc26`: local ordinary
1234 / 9593 / 0 (seed 36939, 94.94s), then system 65 / 1131 / 0 (seed 39809, 156.89s).
Exact-SHA CI 38105072186 passed all four jobs with those actual counts and PostgreSQL
17.11. PR #90 merged as `c3985b450b8ce48887e0d1b56768306fe51b7a82`; tree matches
candidate. Actual-main CI 38105389468 passed all four jobs, including actual serial
ordinary/system steps. #80 is complete. No production inspection, mutation or deployment.

## #77 Member/delegate occurrence and document parity

Design/evidence: [Member Meeting API reads](../MEMBER_MEETING_API_READS.md). Original
application `34d6abd`: 2 / 3 / two failures, 403 member list and actual agenda-only
transcript/working-minutes summaries. No full transcript text leaked by that response.
Repair uses authenticated baseline occurrences, explicitly member-safe document endpoints,
and current-capability filtering on all Meeting payload consumers, including update and
agenda-delete echoes. Existing officer endpoints retain their authority checks.

Final focused neighbor checks before commit: 66 / 1605 / 0 (seed 47107, 10.71s), covering
API Meeting/handbook/workspace, member HTML/PDF, final occurrence and officer forms.
`MeetingDocumentsTest` 2 / 156 / 0 (20.81s): real browser member bearer JSON and real PDFs,
native/custom protected delete controls, document/archive navigation and readable layouts.
Desktop/390px screenshots inspected. No assertions removed or skips added.

Controlled mutation of only the member document's payload source to mutable working text:
1 / 84 / one saved-heading assertion failure (1.82s); exact-byte restoration then
5 / 506 / 0 (seed 17499, 2.85s). Logs `/tmp/legion-member-{controlled-fault,restored-clean}.log`.
No experimental source fault remains. Metadata/detail now share one selected revision.
RuboCop 497 files clean; Brakeman zero errors/warnings; dependency audits clean.
Full committed-candidate suites/CI and actual-main verification remain required.

#77 final candidate `63bbaa67ab79617391ae04f5407f2fc084cf2465`: local ordinary
1241 / 10158 / 0 (seed 24820, 104.19s), then system 65 / 1160 / 0 (159.19s).
Candidate CI 38105684973 passed all four jobs with the same actual counts on PostgreSQL
17.11. PR #91 merged as `b47d10ee25788f01e4d497200b69b545d17a29be`, identical tree.
Actual-main CI 38106040386 passed all four jobs and those serial ordinary/system steps.
#77 closed with completion evidence; no production inspection, mutation or deployment.

## #78/#92 current duties and cached response authority

Designs: [officer authority](../OFFICER_AUTHORITY_VERIFICATION.md) and
[delegated retry authority](../DELEGATED_RETRY_AUTHORITY.md), written before their
respective implementation. Existing User, position-grant, assignment CRUD, API and
last-administrator protections remain. Normal dated resolution already satisfies the
independent Commander/Adjutant/1st Vice matrix at a consistent date; the older table
was stale. The named original Post installation correction remains historical context.

On unchanged main `b47d10e`, the initial corrected request matrix ran 4 / 202 / one
failure: an exact cached minutes write returned its private heading after the same
token owner's Commander term expired. Persisted minutes did not mutate on retry.
#92 records this disclosure; inactive-token coverage alone could not detect duty loss.
`authorize_with` registers the existing current-authority callback for normal execution
and replay. Lookups, optimistic locks, state checks and official consumption are not
repeated. All routed mutation actions are inventoried; an unregistered replay fails closed.
The former website-only callback ordering workaround is replaced by this shared guard.

Existing calendar, Endeavor creation and Adjutant attestation tests now retain their
previous assertions and add exact lost-authority retries, unchanged execution/records,
and restored-authority receipts. A deleted calendar target still returns its permitted
original receipt. Calendar normal/replay checks explicitly share the Post local date.
The broader cross-controller date decision is separate #93: near UTC/local midnight,
dashboard/calendar and minutes editing currently have differing Date.current contexts.
No broad date resolver or authority policy was silently changed.

New real-request matrices cover future/start/inclusive-end/expired/inactive/renamed
positions, manual drafting exceptions, honorary offices, opposite official duties,
and actual human later-Meeting approval by each configured officer without manual grants.
The existing full browser correction/PDF journey now uses configured office duties.
Same-session subsequent expiry denial and member navigation pass at 1400px/390px;
screenshots inspected, readable wrapping/no horizontal overflow. Corrected focused
browser run: 3 / 131 / 0 (seed 55474, 21.18s). An initial new fixture used yesterday in
the server date while it was still today in the Post date; this exposed #93 and was
corrected to a genuinely past date in both contexts. No navigation assertion was removed.

Test-helper review: JSON GET-with-params mutates the supplied integration headers with
X-Http-Method-Override GET in the installed Rails runner. Reusing those headers made later
official POSTs become GETs. Membership reads now use query-string input; actual route
expectations and duties are unchanged. Earlier helper/fixture failures are excluded from
product-regression evidence. One exploratory short browser invocation overlapped the tail
of a focused request run; the serial corrected browser run and final full suites qualify.

Controlled expiry fault removed only the first assignment end-date SQL predicate.
Both Commander and Adjutant scenarios fail on changed persisted draft attributes after
an expired-office API PATCH, before checking the response: 2 / 73 / two failures
(1.87s). Python finally restored exact User bytes, SHA-256
`a8d8de63cd4522a00867abbe0202baa242753eddb0fb9d98deb0588ca697e1f9`.
Logs `/tmp/legion-officer-expiry-content-fault.log` and restored clean run below.
An earlier probe also caught the formerly forbidden editor opening; the stronger probe
demonstrates record mutation detection. No experimental application fault remains.

Expanded API/role/official-confirmation neighbor run: 198 / 2095 / 0 (seed 25822,
19.47s). RuboCop 499 files / no offenses; Brakeman zero errors/warnings; both dependency
audits clean. The final restored focused run and committed-candidate full serial suites,
exact-SHA CI, fresh review and actual-main verification are still required before merge.

Restored focused request/inventory/calendar run after the stronger fault: 26 / 444 / 0
(seed 64008, 5.81s), then changed-test lint passes. All previous assertions are retained.
Fresh review confirms 21 controller edits are exact existing-guard declaration changes;
the three special controllers implement replay, calendar date preservation and removal
of the old editorial callback workaround. Ten local Markdown references resolve.

First committed candidate `6045eb2`: local ordinary 1250 / 10453 / 0 (seed 42258,
101.08s), then system 66 / 1187 / 0 (seed 6064, 163.91s), serially. Exact-SHA CI
38106906481 passed all four jobs. PR #94 remains draft: fresh review then found a
partial-authority receipt case before merge. A manual agenda grant may survive office
expiry, so action authorization remains valid while its old Meeting receipt still exposes
restricted transcript/minutes summaries. Reproduction at `6045eb2`: 1 / 4 / one failure
(seed 17260, 1.38s), with actual transcript creator/source metadata returned. No full
transcript text or repeated mutation is claimed.

Fresh Meeting responses, direct workspace read guards and cached Meeting receipts now
reuse the same minutes/transcript visibility predicates. Redaction affects the returned
copy only; stored execution, source graphs and safe historical receipt fields stay intact.
The added partial/selected/restored authority case checks original byte-identical receipt
restoration without another write. A deleted unreferenced agenda receipt also remains
available with surviving agenda authority while hiding the expired minutes summary.
The new fixture initially changed the Meeting type without matching draft-minutes context,
so its subsequent minutes save correctly failed validation; the synthetic fixture now
sets matching draft context. No application validation was weakened.

Focused changed replay/API neighbors: 70 / 866 / 0 (seed 29799, 12.28s); four changed
Ruby files pass lint. This source change requires a new committed candidate, serial full
suites and exact-SHA CI; the earlier passing candidate is not substituted as final proof.

Final replay candidate `31231f6`: ordinary 1252 / 10484 / 0 (seed 17790, 140.68s),
followed by qualifying serial system 66 / 1187 / 0 (seed 65277, 162.64s). The earlier
passing system run at seed 43330 overlapped one short independent API probe and is
excluded. RuboCop 499 files clean; Brakeman zero errors/warnings; both audits clean.
Exact-SHA CI 38107402806 passes all four jobs and actual PG17.11 suites with matching
counts. Its first attempt encountered Chrome154's detached-node inspector error during
a website-token visibility check; the expected page was present in the screenshot. One
failed-job rerun completed all retained assertions; no tests suppress errors or retry.
Fresh review checked callback scopes, partial returned-copy redaction, deletion/stale
receipt continuity and official once-only provenance. PR #94 merged as
`0a5686a92bc0203085497fc4f3e75a8c6d8b5215`; exact merged tree matches the candidate.
Actual-main CI 38108458080 is pending at this entry. #92 closed; #78/#93 remain open.

## API guidance / actual delegated and website authority (#81)

Design: `docs/API_GUIDANCE_AUTHORITY_VERIFICATION.md`, written before changes. Seven
independent profiles compare JSON/Markdown advertisements to real saved reads, denied
write preservation, drafting and delegated official acts. Original component tests remain.
Full existing handbook/website-access/operator/token-management contracts are reviewed;
other API files remain scoped/deferred, rather than claiming suite execution reviews them.
The old internal-viewer test name incorrectly described denial of restricted sources;
rename it to its existing explicit-read contract without changing its assertions.

Strengthened original minutes handoff/attestation checks: exact payload/version/digest,
real owner/token, consumed confirmation, saved attestation/event references and original
byte-identical receipt with unchanged graph. Website matrices add anonymous content
exclusion before 401 and real authenticated empty conditional 304 before revocation.
Correct the standing brief's anonymous-feed claim and label the dated August parity
outline historical, linking current policy/member reads without rewriting history.

Detection: bad Administrator approval advertisement 1 / 19 / one failure; missing website
credential fault 1 / 2 / one failure exposing actual fictional person content; restored
old brief 1 / 2 / one failure. Exact-byte restorations and hashes are in the design.
Initial caller-ID assumption failed because the handbook has a name field; use that real
field. No permission or route expectation relaxed. Final restored focused set: 38 / 1482 /
0 (seed 64533, 9.87s), log `/tmp/legion-guidance-restored-clean.log`; five changed Ruby
files lint clean. No application fault remains. Final committed full serial suites,
security, exact candidate CI and actual-main evidence are required before merge.

Replay actual-main CI 38108458080 now passes all four jobs for `0a5686a`, including
actual PG17.11 ordinary 1252 / 10484 / 0 and system 66 / 1187 / 0. #92 completion
comment records exact-tree/source/local/CI evidence; #78/#93 remain open.

API final candidate `43073c3`: full ordinary 1260 / 11151 / 0 (seed 19249, 101.20s),
then serial full system 66 / 1187 / 0 (seed 24138, 163.21s). Lint 500 files clean;
Brakeman zero errors/warnings; both audits clean. Exact-SHA CI 38108689186 passes all
four jobs, with actual PG17.11 counts matching local suites. Fresh review confirms
independent expected duties, denied content/persisted preservation, exact official
provenance and no remaining experimental faults. PR #97 merged as
`08a7094eade6acb6601a6884fd0700ac04b404e3`, exactly matching the candidate tree;
actual-main CI 38108959812 is pending at this entry. #81 completion waits for that check.

Transcript retention decision draft is committed as `f371ab1`, reviewable in draft
PR #98. Current source/ref/diff checks pass; start boundary is still pending, with no
dependent implementation or deletion. #79 stays open. This is not an implementation
or production retention claim.

## Endeavor SQL guards and recorded delegate provenance (#88/#95)

Design written before tests: `docs/ENDEAVOR_HISTORY_DATABASE_GUARDS.md`. All existing
offline HistoryTest variants reviewed and retained, including citations/coverage,
publication, source changes, immutable callbacks, budget/reuse/recovery and historical
account continuity. The six inventoried triggers need behavioral proof independent of
model callbacks. New tests compare saved rows before exact SQL refusal messages/types.

Original source `31231f6` in fresh schema: 19 / 143 / two failures (seed 56824,
3.61s). Pending/running jobs' recorded token
can change. The other guard variants pass. This changes the worker's checked credential
and persisted provenance; no ordinary API exploit or production incident is established.
#95 tracks the narrow fix: one reversible function replacement adds only token identity
to the existing conditions, retaining legitimate progress and system nil-token input.

Controlled edition-trigger fault within the test transaction: 1 / 1 / one failure,
actual saved payload changed before any SQL error assertion. Exact bytes restored,
transactional DDL rolled back; all 13 real triggers are enabled. Fault hash and fixture
refinement are documented in the design. Initial nil-token multi-state fixture correctly
hit the one-active-run index; split scenarios and use nil requester for system fixtures,
retaining that index and all expectations.

Normal owned-database migration/down/up verifies previous and full repaired function
definitions (normalized whitespace only). Intended SQL schema bytes restored exactly
after normal dump; diff is only token condition plus migration version. Fresh normal SQL
load and round-trip guard cases: 33 / 226 / 0 (4.04s). Final current-main focused guards,
all offline pipeline tests and official guards: 76 / 436 / 0 (seed 24640, 11.48s).
Existing recovery now retains original token/run/event identity; a real revoked-token
request fails before the offline provider, preserving source rows and publishing nothing.
Changed three Ruby files lint clean; diff checks pass. Full committed serial suites,
security, exact-SHA CI and actual-main verification remain required before merge.

API actual-main CI 38108959812 passes all four jobs for `08a7094`, with PG17.11
ordinary 1260 / 11151 / 0 and system 66 / 1187 / 0; #81's completion comment records
all four bounded acceptance criteria and distinct wider/live-publisher limits.

Final Endeavor candidate `2e81fc1`: ordinary 1282 / 11350 / 0 (seed 8610, 103.22s),
then qualifying serial system 66 / 1187 / 0 (seed 1423, 162.21s). RuboCop 502 files
clean; Brakeman zero errors/warnings; both audits clean. Exact-SHA CI 38109379381 passes
all four jobs with matching PG17.11 counts. Fresh review confirms token assignment only
at creation/recovery, nil system input and retained progress/terminal/source guards.
PR #100 merged as `4d7f67f22d6ccb076e991f9c877c910f425014af`, exact candidate tree;
actual-main CI 38109687314 passes all four jobs with the same actual counts. #88/#95
completion comments distinguish direct SQL evidence from ordinary API/production claims.

## Configuration, shell and strict receipt cutoff review (#96)

Design: `docs/testing/CONFIGURATION_AND_SHELL_REVIEW.md`. Retain all configuration,
filter, timezone, asset, entry/navigation and account-menu contracts; their distinct
parsing, process, content, selector and actual-browser failure modes justify no deletion
or consolidation. Strengthen the existing production refusal for every required key,
clear inherited dummy-build mode, check supplied identities/host, and add an exact frozen
thirty-day retained receipt to the original real cleanup job scenario.

Original new-worktree request slice lacked built Tailwind assets (29 / 44 / 17 asset
errors). Build existing assets, retaining assertions; corrected 29 / 135 / 0.
Queue-requirement fault: 1 / 7 / one failure, with earlier primary/cache variants passing.
Inclusive cleanup fault: 1 / 4 / one failure on the deleted boundary row. Exact original
config/model hashes restored; no source fault remains. Restored 29 / 135 / 0 (seed43826,
4.88s), then integrated verified main `4d7f67f`: focused 29 / 135 / 0 (seed51930,
6.07s). Two changed Ruby files lint clean; diff checks pass. Hashes/logs and the initial
local-draft-before-tracking sequencing exception are recorded in the design/#96.

All eight reviewed file inventory entries now describe actual assertion/runner limits;
remaining files stay deferred. #99 separately reproduces/documents finite cached retry
behavior; cleanup is not a hard API expiry timer or infinite once-only guarantee.
This committed slice still needs final serial suites, security, exact-SHA CI and
actual-main verification before completion. #84 remains open.


## Finite bearer receipt guidance (#99)

Design: `docs/FINITE_RECEIPT_GUIDANCE.md`. Strengthen the existing same-request retry
scenario without removing its assertions: actual saved creator/business fields, frozen
exact 30-day cleanup retention, 31-day retained replay before cleanup, actual receipt
removal and subsequent second distinct Endeavor/new receipt under the original key.
A 90-day token isolates receipt cleanup from credential expiry; the original record
remains unchanged. Current authority/visibility filtering remains the separate #92 contract.

Original live guidance fails the independent duration expectation (2 / 40 / one failure,
2.42s), while the actual finite runtime behavior passes. Revised shared JSON/Markdown
prose and standing instructions direct older uncertain mutations to current saved state
and the human. No retention or mutation behavior changes. Revised two contracts:
2 / 58 / 0 (seed30718, 3.35s). Neighboring authority/retry/concurrency/inventory matrix:
51 / 852 / 0 (seed32818, 7.76s); after integrating actual main `b852211`:
51 / 852 / 0 (seed38320, 7.71s). Changed three Ruby files lint clean; diff checks pass.
An initial command named nonexistent files; corrected to the actual inventoried paths,
without changing tests. Full candidate serial suites/security/CI remain required.

Configuration candidate `2eb7d6c98ff39fe5bd43441a36a864534b15788c` passed ordinary
1283 / 11367 / 0 (seed55877, 103.68s), then serial system 66 / 1187 / 0 (seed29389,
162.52s). RuboCop 502 files clean, Brakeman zero warnings, audits clean. Exact-SHA
CI38110200711 passes all four jobs with matching PG17.11 counts. Fresh review retained
all old cases/assertions and restored sources. PR #101 merged as
`b8522118fe1b2b4a5d8b7ac6675aeb51f7a8e09c`, exact tree; actual-main verification follows.
#84 remains open; #99's scoped officer API retry review does not establish full-file review.

## Repeated website-token inspector error and native navigation (#105)

Main configuration CI38110689517 passes all four jobs on `b852211`, actual PG17.11
1283 / 11367 / 0 ordinary then 66 / 1187 / 0 system; #96 completion comment records it.
Finite retry candidate `ab4e4f4` passes local ordinary 1283 / 11409 / 0 (seed18274,
107.75s), then serial system 66 / 1187 / 0 (seed23237, 162.04s); lint502/security clean.
Its CI38110781740 ordinary count matches; browser 66 / 1174 / 0 failures / 1 inspector
error in the unchanged website-token creation journey. This repeats the earlier Chrome154
node/document error, so PR #103 stays draft and no green-seeking rerun is performed.

#105 design: `WEBSITE_TOKEN_BROWSER_RELIABILITY.md`. Expected creation-page failure
screenshot reviewed; native creation deliberately bypasses Turbo. Add meaningful exact
path assertion after real POST and before DOM query, preserving every old assertion;
rename the journey to actual viewed-once evidence, not untested clipboard contents.
No driver rescue/retry/sleep or application change. Exact Chrome154 version unavailable
in official testing manifest; local152 proof is distinguished from pending exact CI.
Focused request/model20 / 181 / 0; website/personal real browser2 / 37 / 0. Created/list
1400/390px screenshots inspected. Controlled wrong redirect fails new native-path outcome
1 / 8 / one failure; controller restored exactly (hash in design). The race explanation
remains inference; later full suites and CI are needed before merge, and future recurrence
must not be hidden by broad error suppression.


Website-navigation candidate `db6c1686ddc8dc69b4d48127b5fec938c33de9ab` passes ordinary
1283 / 11367 / 0 (seed9871, 101.86s), then qualifying serial system 66 / 1188 / 0
(seed38538, 162.38s). Lint502 clean; Brakeman zero errors/warnings; audits clean.
Exact-SHA CI38111233748 passes all four jobs with matching PG17.11 counts. PR #106
merged as `8a603bb7b1a3105296bee14b66cf607cdcae015a`, exact candidate tree; actual-main
CI38111511575 is pending at this recording. #105 remains open for precise inspector
cause and untested clipboard contents. This is native-navigation outcome proof, not
proof of the inferred document-transition race.

Integrate #106 main into finite-retry PR #103. The two append-only ledger/matrix
conflicts preserve both sections; inventory merges retain each distinct reviewed row.
No application fault, dropped prior assertion or green-seeking CI rerun is included.
The new combined committed candidate must repeat final serial suites and fresh CI.


## Configured Post title update and retained officer/account contracts (#107)

Original new foreign update request on `b852211`: 1 / 1 / one saved-graph failure
(seed22537, 2.08s), before 404. Fix only global title lookup to the configured first
Organization association, matching index/create/reorder and assignment creation. Corrected
8 / 53 / 0 (seed10714); integrated main `66e8c8a` neighboring authority/account checks
87 / 626 / 0 (seed9012, 4.71s). Every original assertion remains; no new authority policy.

Real browser initially assumed a static error page for Turbo (actual 404 retained old
screen), then encountered configured Rails detailed test exceptions for native submission.
Record both 1 / 3 / failures; don't change application error handling to fit the harness.
Only this test hides/restores exception details with :rescuable unchanged, and only its
foreign form uses native submission. Corrected native-public-404/unchanged saved authority
plus later ordinary Turbo controls pass 1 / 31 / 0 (seed51262, 4.54s). Restored positions
screens manually inspected at 1400/390px, readable and no overflow. Three Ruby files lint
clean; complete intended diff reviewed. Design/source limits in POSITION_TITLE_UPDATE_SCOPE.
Final committed serial suites/security/exact-SHA CI remain required before merge.

Finite receipt candidate `209f9e01c9b681974a3e0a61f4fbd7512113991e` passes ordinary
1283 / 11409 / 0 (seed52822, 102.80s), then serial system 66 / 1188 / 0 (seed57558,
161.64s); lint502/security clean. Exact CI38112043877 passes all four jobs, matching
PG17.11 counts. PR #103 merged as `66e8c8a51dab2251f20d9c0932773abfeb58d603`, exact
tree; actual-main CI38112280346 remains pending at this recording. #99 stays open until
that verification. Prior inspector error/cause and clipboard gap remain #105, not hidden.


Receipt actual-main CI38112280346 now passes all four jobs on `66e8c8a`, matching
PG17.11 ordinary 1283 / 11409 / 0 then system 66 / 1188 / 0. #99 completion comment
records exact local/candidate/main evidence and remaining #84/#105 limits; #99 closed
only after this verification. No release or production action.


## Position-scope actual-main completion and passkey refusal slice

PR #110 merged as `a88f11e2c2c3da16e7f8e44a563ff9f1a3d25c63`, exact reviewed
candidate tree. Actual-main CI38112918755 passes all four jobs, PostgreSQL17.11 ordinary
1284 / 11422 / 0 then system67 / 1219 / 0. #107 closed only after that verification
(comment6105643999); simultaneous final-administrator removal remains open #112.

#104 retains all old authentication assertions and strengthens generic refused saved
state plus real signed authentication refusal/recovery from fresh cookie-free browsers.
Integrated neighboring auth76 / 801 / 0 (seed21487); verification fault1 / 4 / one
saved-metadata failure (seed53734), exact SHA restored; clean passkey25 / 230 / 0
(seed64993). Existing real browser4 / 102 / 0 (seed36848) on preceding main66e8c8a;
1400/390 continued-enrollment images inspected, readable/no overflow. No runtime auth
change, test consolidation or deletion. All eleven distinct neighboring files reviewed
and retained; source and execution limits in PASSKEY_REFUSAL_REVIEW. Final committed
serial suites/security and candidate/main CI remain required before merge.


## Empty attached National roster and subsequent valid upload (#111)

Candidate nil-header hypothesis disproved on unchanged application: CSV3.3.6 parse
returns a Table with empty headers, original new parser/upload contracts2 / 48 / 0.
Keep app source exactly. Empty-header validation bypass leaves partial-header refusal
intact but fails both new checks2 / 9 / two failures (seed8913); exact parser SHA restored
(in EMPTY_ROSTER_INPUT). Expanded roster75 / 470 / 0 (seed35763). Real file upload,
refusal, actual Import another roster link and valid recovery plus old result journey
2 / 27 / 0 (seed41034). All four1400/390 failed/completed images inspected: readable/
no overflow, existing global-error row heading limit recorded. All five complete roster
files reviewed/retained; no test deletion/consolidation. Integrate main283911d; final
focused/committed serial suites/security and candidate/main CI still required.


Integrated #111 focus75 / 470 / 0 (seed4814, 2.79s), browser2 / 27 / 0
(seed45162, 5.02s), changed Ruby lint clean/diff reviewed/source SHA exact. Candidate
retains every prior assertion and contains no application file change. PR #113 passkey
review is merged as283911d6e834aefa572180cbcf0a48caae88e5df; exact CI38113455501 passes
PG17.11 ordinary1285 / 11464 then system67 / 1219. Final local candidate61090d8 runs
ordinary1285 / 11464 (seed47482,105.01s), then system67 / 1219 (seed7601,170.60s),
all zero failures/errors/skips, lint503/security clean. Actual-main CI38113727296 is
pending; #104 stays open until that verification. No production operations.


## Last-administrator overlap reproduction and shared repair (#112)

Initial observer cached pg_blocking_pids caused harness timeout1 / 4 / one error
(seed2003); actual DELETE was blocked but cached observer state stayed empty. Uncached
actual SQL observation reproduces original zero stored enabled admins1 / 7 / one failure
(seed27822,0.92s), before response assertions. No injected authority predicate.
Shared User ordered target+administrator transaction moves real grant replacement and
last-admin checks together with existing disable/roster operations. Every replacement
and manual disable now enters locks before current authority tests, including initial
non-admin targets. Capability validation/automatic-role filtering/refusal policy remain.

Initial corrected three real races3 / 63 / 0 (seed63849); initial neighbors92 / 728 / 0
(seed503); two-line lock-scope refinement92 / 728 / 0 (seed17516). Integrate mainf5fc283,
expanded neighbors123 / 968 / 0 (seed15636), browser1 / 22 / 0 (seed34244); new explicit
three-independent-PG-connections assertion requires final focus recorded next. Both
1400/390 refusal images inspected, readable/no overflow; local National-provenance
mismatch linked separately #115. No old assertions dropped or fault remains.

Passkey PR #113 actual-main CI38113727296 passes all four jobs on283911d, PG17.11
1285 / 11464 then67 / 1219. #104 was auto-closed at merge because GitHub parsed the
conditional PR close instruction; actual-main verification followed and completion comment
6105726560 records that timing truthfully. Pending PR wording corrected to prevent that
premature automation. #104 bounded criteria now verified; no policy/runtime auth change.

Empty-roster PR #114 candidatebf1453a passes local ordinary1286 / 11508 (seed39891,
105.47s), then serial system68 / 1237 (seed41065,172.75s), lint503/security clean.
Exact CI38113975510 all four jobs passes matching PG17.11 counts. Merged asf5fc2832a605de861c15f2031021594903e0e7e1,
exact candidate tree; actual-main CI38114329402 remains pending and #111 stays open.
No application roster change, deployment or production operation.


Final #112 integrated focus123 / 971 / 0 (seed4316,10.45s); refined browser1 / 22 / 0
(seed34244,4.68s); four changed Ruby files lint clean/full intended diff reviewed. Explicit
actual observer/request backend IDs are distinct; no predicate stubs or experimental faults.
Final committed qualifying suites/security/candidate and main CI remain pending.
Empty-roster actual-main CI38114329402 now passes all four jobs onf5fc283, matching
PG17.11 ordinary1286 / 11508 then68 / 1237. #111 completed only after that verification;
no application roster edit or production action. Broader #84 remains open.


## Actual-main administrator completion and personal token refusal (#112/#102)

PR #116 candidate85536255 merged as main877c18e. Actual-main CI38115173719 passed all
four jobs on PostgreSQL17.11:1289/11574 ordinary, then69/1259 browser; no failures,
errors or skips. #112 closed after checking actual-main logs and posting completion
evidence (comment6105915895). No production operations.

Personal token #102 integrates that main in its isolated worktree. Correctly shaped
wrong-secret model refusal and real cookie/bearer refusal strengthen existing tests;
all old cases remain. Guard-only faults fail saved-use metadata before nil/status,
finally restore model SHA83245346397165c589e4aa0ce48f87399733840fbd25a1259ff8fe73f7a2adc4.
Complete credential/API focus43/286, seed33457,3.31s passes; final committed serial
suites/security/candidate/main CI remain required. Whole source/assertion scopes and
limits are in PERSONAL_TOKEN_AUTHENTICATION_REVIEW.md; no application change or safe
removal/consolidation is demonstrated.

## Independent raw-source privacy contracts (#79/#84)

Retain all old cookie/HTML/provider/structured-generation assertions. Both source retention
choices now have real bearer durable receipt/replay/error/current-grant-loss expectations;
nonblank HTML error input proves safe summary plus intentional authorized retry text.
Actual adapter with supplied offline SDK error proves safe failed-run metadata and unchanged
minutes/source. Initial fixture precondition54/494/2 fails because the locked SDK default
message omits nested source; inspect constructor and explicitly supply raw message, keeping
all safe-message/category assertions. Corrected focus54/531 seed7173 clean, restored
focus54/531 seed29075 clean, real browser1/33 seed18317 clean at1400/390. No paid call.

Four faults detect raw creation receipt1/9/1 seed50823, HTML summary1/14/1 seed55779,
provider message1/5/1 seed30626, persisted failed run1/5/1 seed59110. Finally restores
exact API/form/provider bytes; hashes in TRANSCRIPT_SOURCE_PRIVACY_REVIEW.md. All old
component cases stay, large API/generation files are scoped rather than fully certified.
Existing smaller transcript typography is separately linked #120 with rendered-size
reproduction required; no visual-floor pass claimed. #79/PR#98 still require the unresolved
recovery-start decision and actual scheduling/deletion. Main integration/final suites/CI
remain required before merge. No production, member-data copy, deployment or provider call.

## Roster identity and offline audience coverage (#108/#109)

Combined scoped coverage-only candidate integrates main55e091f (PR#118). No application
change proposed. Original stale-client call, later-contact break and same-alert invalid
identity-write faults each fail1 /1 /1 on independent actual calls/payloads/saved graph;
service/controller exact bytes restored in finally. Logs and SHA values are in the two
designs. All old controller/User/audience/client/sync/admin assertions remain; the old
single-contact rejection test is renamed to describe what it actually proves.

Refined focus54 /260 /0 seed7997,1.71s; real partial-output/email-choice browser2 /105 /0
seed51884,9.75s. Existing target and foreign grants make preservation non-vacuous.
Actual screenshots were critiqued at1400/390 for source/refusal/error text and overflow.
The first browser setup errors and corrected Profile expectation are documented honestly.
Fresh integrated focused checks, final committed serial suites/security/candidate/main
CI remain required. Main PR#118 CI is pending at this note; #102 stays open.
No external provider calls, production, paid AI or real member data.
## Native calendar browser navigation and retained publication components (#105)

PR #118 candidatea8989831 passed exact CI38115989210, PostgreSQL17.11 ordinary1289/11583
then browser69/1259. Normal merge produced main55e091f. Actual-main38116220723 passed
ordinary but browser69/1243 had one Chrome154 inspector error in the unchanged calendar
journey. No failed-job retry; #102 remains open and further independent code merges held.
Exact artifact shows expected desktop preview; native form posts to a distinct preview
path. Add one exact-path assertion after that click, retaining every old assertion. This
is bounded navigation evidence, not a precise Chrome-cause diagnosis or a changed app flow.

Whole six request/nine policy cases reviewed with explicit privacy/authority/token/ETag/
official-document distinctions and limitations; focus15/97 seed59451 clean. Browser1/21
seed54187 clean, desktop/narrow actual screenshots inspected. Wrong redirect fault1/4/
1 failure seed25561 at new path assertion; finally restores exact controller SHA256
f91f243e6e6eb0f33f56f6bec8cdb5f783e501b60a7186f57f7102210ea375f5.
Final committed serial suites/security/exact candidate and actual-main CI remain required.
No production operations, provider calls, dependency upgrades or exception suppression.


## Actual synthetic token copying (#121/#105)

Retain both credential journeys and every old assertion. Real clipboard readback plus
actual denied-write manual fallback pass2/49 seed44498; full stored token attributes
remain unchanged. Success-label-without-write fault fails2/24/2 seed56311 at exact
copied bytes, then restores JS SHA2562b62abaf98f9a2df5af834c2c563674caa8157e8cf4ae89265a33e783e0b4f9b.
Created/list desktop1400/390 captures inspected; synthetic redaction follows copy proof.
Native-navigation exact-path evidence remains separate from unknown Chrome internals.
Three changed Ruby files lint clean. Final main integration, committed serial suites,
security/exact candidate/main CI pending; #121/#105 remain open. No app or production change.
Integrate calendar merge42a3154 after exact candidate24769f2/all-four CI38117274225
passes PG17.11 ordinary1289/11583 then69/1260. Preserve both evidence sections and
all privacy tests; original source/API/provider fault-target bytes remain unchanged.
Actual-main38117583145 and this candidate's final qualification remain pending.
Roster candidate07aa328 passed committed local ordinary1290/11644, seed18337,104.84s,
then browser71/1364,178.55s, no failures/errors/skips. Full lint507, Brakeman0/0, gem
and importmap audits passed. Later main55e091f browser CI failed as recorded above;
no independent merge proceeded. Calendar PR#119 candidate24769f2 passes exact all-four
CI38117274225, PG17.11 ordinary1289/11583 then69/1260, merged as42a3154 with identical
tree. Actual-main CI38117583145 is pending. Integrate that merge here, retaining both
ledger sections; service/controller fault-target hashes still match their exact originals.
Repeat final committed serial suites and exact candidate/main CI before roster merge.


Integrated roster main15ce51b with all-four exact main CI38118516754, PG17.11
1290/11644 then71/1365, no failures/errors/skips; #108/#109 completed. Preserve both
review sections and distinct inventory rows. Final clipboard qualifying serial suites
and exact candidate/main CI remain required; no app fault remains.
## Whole-source review navigation and retained component distinctions

Twenty-nine directory/account/roster/display/privileged-confirmation/Dashboard files
reviewed in bounded groups are mapped in two source-only documents and a pinned exact
case-name/source-line index. Remaining Deferred rows stay open with their priorities.
Actual-main15ce51b CI38118516754 executes the unchanged reviewed components, PG17.11
ordinary1290/11644 then system71/1365. This documents execution separately from fault
proof; no blanket failure-detection or redundancy claim. Completed #108/#109/#111/#112
have linked independent evidence. Local provenance#115/invitation#117 and Post-date#93
remain open. No test removal, app edit or production/provider operation in this slice.
Calendar main42a3154/all-four CI38117583145 now passes PG17.11 ordinary1289/11583
then69/1260. Personal-token #102 completed afterward (comment6106216389), preserving
the failed55e091f run. Roster PR#122 exact candidate30fb41b/all-four CI38118111332
passes1290/11644 then71/1365, merged as15ce51b with identical tree. Actual-main
CI38118516754 remains pending; #108/#109 stay open. Integrate that roster merge here,
preserving both evidence sections and all three new browser inventory rows; no app fault
remains. Final privacy candidate qualification/CI still required. No production operation.

Roster actual-main15ce51b/all-four CI38118516754 passes PG17.11 ordinary1290/11644
then71/1365, no failures/errors/skips. This completes the bounded #108/#109 criteria;
the prior failed main55e091f run remains preserved. Privacy integrationc653d70 retains
both ledger sections and unique inventory rows. Qualify this final committed privacy
candidate serially; #79 timing/purge decisions remain open and PR#98 stays draft.


Privacy PR#123 candidate4675856/all-four CI38119147815 and actual-main79bf811
CI38119436435 pass PG17.11 ordinary1292/11778 then72/1398; identical merge tree.
#79 remains open with timing/purge decisions and draftPR#98. Typography PR#126
candidate239baf1/all-four CI38119589531 and actual-main38d6582 CI38119824001 pass
1292/11778 then72/1506; identical tree, #120 completed after main verification.
Source-only PR#125 exact integratedd7bf95f/all-four CI38119906775 passes same counts,
merged5c54e39 with identical tree; actual-main38120256442 pending and #84 stays open.
Integrate all three here, preserve both histories and unique inventory rows. Final
clipboard serial qualification/exact candidate/main CI still required; #121/#105 open.
New source-input#124 independently reproduces valid uploaded UTF-8 read failure and
coupled limit expectation; its work remains isolated/unmerged. No production operation.

## Independent transcript byte boundary and actual Unicode upload (#124)

Whole original seven-case component source review identifies a coupled oversize fixture.
Original raised10MB limit leaves its old test passing1/15 seed4918; fixed existing5MB+1
and a new exact multibyte-byte boundary catch the same restored experiment2/25/2
seed55628 after clean62/674 baseline. Storage/identity preservation, later exact-size
retry and every old assertion remain. Unicode file reading exposes a real original
Encoding::UndefinedConversionError1/10/1 seed64339 after stored raw bytes already agree.
The one-line UTF-8 interpretation repair preserves raw bytes/digest and normalization.
Finally restored repaired model SHA2565810c53d8209d3684dfea147b3f654ee62ccc67f08331c97ace93b1ab3557695;
restored neighbors62/674 seed32829 pass. Three changed Ruby files lint clean.
Actual file controls/read/grant-loss/Profile browser plus retained pasted/privacy/font
journey2/167 seed29413 pass; uploaded reader1400/390 captures inspected. Source5c54e39
integrated; committed final serial suites/security/exact and actual-main CI still pending.
#79 recovery-date decision and actual deletion remain open; no paid AI or production.

Clipboard PR#127 exact candidate7930c76/all-four CI38120823673 passes PG17.11
ordinary1292/11778 then72/1518. Normal merge2b9bf51 has identical tree; actual-main
CI38121399155 remains pending. Integrate it here without changing any original
source-input assertions. Qualify this final committed Unicode candidate serially.

## Thirteen-file minutes source/assertion review

Whole13 files/88 exact pinned cases at5c54e39 retain snapshot/digest, editor,
correction, individual AI review/attendance, manual ledger/retry, source numbering/
prompt, worker chain and distinct real approval/disclosure browser contracts. Reviewed
assertions and concrete limits are documented; no code/test edit, new fault or deletion.
Actual-main5c54e39/all-four CI38120256442 executes unchanged ordinary1292/11778 then
system72/1506 on PG17.11, separate from blanket defect detection. #128 records the
locked Active Job false-result discrepancy in initial HTML/API enqueue before routed
reproduction/smallest repair. Remaining API/Generate/confirmation variants are still
scoped, #93/#79 remain unresolved. Inventory Deferred rows stay open with priorities.

The whole API minutes10 file is now separately indexed/reviewed: actual bearer source
privacy, structured mutations, exact official provenance/replay and grant-loss graph
remain distinct from cookie requests/fake PDF/manually attested fixtures. #131 retains
existing detached Session refusal and records missing direct ten-minute/atomic consumption
proof before component edits; no demonstrated app defect or consolidation is claimed.

Clipboard PR#127 actual-main2b9bf51/all-four CI38121399155 passes1292/11778
then72/1518; #121/#105 closed. Unicode PR#129 exactf4cc577/CI38121785815 and
actual-main e53238f/CI38122104236 both pass1293/11869 then73/1544; #124 closed.
This source-only review integrates actual-main e53238f, preserves all evidence histories
and every existing assertion. Queue#128, queued readability#130 and direct official
confirmation#131 are independently tracked; #78/#93 and #79 decisions remain open.
