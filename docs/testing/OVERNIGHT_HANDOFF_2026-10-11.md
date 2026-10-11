# Overnight issue handoff — October 11, 2026

All acceptance work for #77–#84 is merged and verified. The two requested choices are
implemented: current officer duties and role labels use the saved Post local date;
30-day transcript recovery begins at final minutes approval, including final corrected
Adjutant attestation. The original earlier membership decision remains immutable.

Production was not accessed, deployed, restarted or mutated. No real member data was
copied, paid AI called or external member email sent. The original checkout's modified
README and untracked application-discovery artifacts remain untouched; reviewed copies
were already merged in PR #85. Work used isolated codex branches, locked dependencies,
synthetic records, disposable test databases and real Chromium controls.

Baseline `5adda175d67e9603f58fdf8574ad6f7a0313d6b9` passed ordinary 1190/8881 then
system 64/1014, zero failures/errors/skips, after installing missing repository-locked
gems. Ruby 4.0.7, Rails 8.1.4, local PostgreSQL 18.6 and Chromium/driver 152 were used;
final system runs explicitly use one worker. Dependency versions were not upgraded.

| Issue | Result and merged evidence |
| --- | --- |
| #77 | Complete. PR #91, main b47d10ee: member/token Meeting parity, last-attested/final immutable selection, private-source exclusion, grant loss and actual HTML/PDF. Working-copy fault caught/restored. |
| #78 | Complete. PRs #94/#144, main 86037334: independent Commander/Adjutant policy, actual start/inclusive end/expiry, inactive/renamed positions, surviving manual grants and issued-token replay. Approved Post-local midnight consistency verified in Chicago/Tokyo, End role controls and real sign-out/member reading. Original disagreement and separate date faults caught/restored. |
| #79 | Complete. PR #98, main f56bd35b: actual scheduled-job removal of pasted text and uploaded storage after ordinary/final corrected approval, both policies, exact/delayed/historical deadlines, retained official graphs/metadata, failed-storage/transaction recovery and repeated execution. Original missing-deletion, wrong-clock, omitted-byte-delete and pending-read faults detected. Prior privacy/receipt/UTF-8 work remains. |
| #80 | Complete. PR #90, main c3985b45: all seven final occurrence fields protected independently of agenda state; saved official graphs and subsequent member reads. Separate real PostgreSQL overlap experiment is explicit/manual, not CI-discovered. |
| #81 | Complete. PR #97, main 08a7094e: independent handbook expectations, real delegated/official/website permitted and refused actions, private graphs preserved and no private content before authentication. |
| #82 | Complete. PR #85, main b092bf67: real protected Meeting Type deletion refusal, truthful UI, preserved immutable content and later member reading. |
| #83 | Complete. PR #85, main b092bf67: linked agenda/child deletion protection, AI lineage, saved history and subsequent HTML/PDF. |
| #84 | Complete. All 184 inventory entries reviewed: 183 discovered test files plus one explicit concurrency runner. Seven bounded review slices, exact pinned cases, linked gaps and independently verified repairs are recorded. Source review, execution and fault detection remain distinct. No test deletion/consolidation was justified; unique component coverage remains. |

[The change index](OVERNIGHT_CHANGE_INDEX_2026-10-11.md) lists every scoped PR,
candidate commit and merged SHA. [The ledger](OVERNIGHT_REVIEW_2026-10-10.md) records
original failures, restored experiments, exact commands/seeds/environment and CI.
[The workflow matrix](WORKFLOW_VARIANT_REVIEW.md) and
[inventory](TEST_FILE_INVENTORY.md) distinguish bounded source review from demonstrated
behavior. Remaining source-only slices review 85 whole files / 707 exact declarations;
those pinned historical indexes are not blanket fault proof.

Final code candidate 4c7bc3b429f306d882b759c8517a6ee5aa356113 (PR #98) merged normally
as f56bd35b9d3fe2a8fce45efa3dc1c5490deef126 with an identical tree. Committed local `bin/rails test`:
1334 runs/13206 assertions, zero failures/errors/skips (seed65370,104.934150s).
Then serially `CI=true PARALLEL_WORKERS=1 bin/rails test:system`:78/2041, zero
failures/errors/skips (seed52932,193.590050s). Full RuboCop 518 clean, Brakeman 0 errors/
0 warnings, gem/importmap audits clear. [Exact code CI38137509223](https://github.com/AndreRobitaille/LegionPostTools/actions/runs/38137509223)
and [actual code-main CI38137887001](https://github.com/AndreRobitaille/LegionPostTools/actions/runs/38137887001) pass all four jobs with the same ordinary/system totals.
These counts accompany persisted-state, later-action and original/fault evidence; they
are not a claim that every user workflow or external dependency is proven.

Browser evidence retains real magic-link sign-in/sign-out and later protected denial,
member navigation, officer agenda/minutes/confirmation workflows, relevant native PDFs,
grant loss, protected deletion and publication boundaries. The new source reader covers
actual Unicode upload, pending corrections, final local deadline, failed deletion,
unavailable reader, actual storage retry/completion, current source JSON and unchanged
final member minutes. Scheduled/pending/completed states are visually inspected at 1400/390; values and status
copy are 16px, labels 13px, with no horizontal overflow. The officer-date
journeys and End role controls were also inspected at both widths.

Cleanup clarified finite receipt lifetimes and the retry scenario's actual contract,
replaced racy native-page reads with meaningful waits, centralized the renderer's browser
time budget while preserving ordinary waits, and restored print media even after failure.
Original relevant components and assertions remain; representative faults still fail
before exact restoration and clean neighboring runs. Additional actual repairs include
immutable SQL guards, confirmation cookie continuity/expiry/rollback, cached current
authority, foreign-position mutation, the last-administrator race, upload encoding and
rejected queue enqueue. Exact before/after evidence is linked from each matrix slice.

No product choices or required scope work remain. All experimental faults were restored;
no skips, broadened permanent grants, official-record editing shortcuts or indiscriminate
exception suppression were introduced. The storage adapter's varied IO errors are
translated only at its narrow boundary; the job still reports failure and retries safely.
Local PostgreSQL 18.6 and CI PostgreSQL 17.11 both pass; Chrome versions differ as recorded
in the ledger.

Release review remains separate. Deploying this code will make already-due historical
final sources eligible from their original finalization date; it will not grant them a
new 30-day window. The hourly task can remove them on its next run, in batches of 500.
Synthetic application deletion does not prove erasure of external recordings, downloads,
provider-held data or independently managed backups. Live production scheduling/storage,
paid-provider behavior and backup erasure remain unverified. Existing #43/#60–#62 and
other roadmap work stay open; they are separate from this completed review. Production
remains on its existing release.

The reporting-only PR and its final main verification are recorded in the
[#84 completion evidence](https://github.com/AndreRobitaille/LegionPostTools/issues/84).
