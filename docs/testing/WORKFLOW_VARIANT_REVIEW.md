# Workflow-variant evidence matrix

Baseline `5adda175d67e9603f58fdf8574ad6f7a0313d6b9`; synthetic test database;
ordinary baseline executed with seed 2911: 1190 runs, 8881 assertions, no
failures/errors/skips. Execution does not establish detection of an untested variant.
System baseline passed: 64 runs, 1014 assertions, no failures/errors/skips. All variants outside this matrix remain explicitly deferred
in [file inventory](TEST_FILE_INVENTORY.md); #84 stays open.

| Variant / policy | Existing test and level | Assertion review | Baseline execution | Detection / next work |
| --- | --- | --- | --- | --- |
| TPL-03 unused type / protected deletion design | `Admin::MeetingTypesControllerTest#destroy deletes a meeting type and its items` (request) | Asserts type/item counts, redirect and exact success; useful positive path retained | Passed in ordinary baseline | Does not test populated references; #82 adds refusal/preservation variant |
| TPL-03 actual delete/confirm | `MeetingTypesSystemTest#deleting a meeting type after confirming` (browser) | Real row control/native confirmation; row disappearance and database nonexistence | Passed in system baseline | Preserved: catches Turbo/confirmation/control failure that request test cannot |
| AGN-02 agenda delete | `Admin::DatedAgendasControllerTest#destroy removes the agenda but keeps its meeting` (request) | Counts, surviving Meeting and success message | Passed in ordinary baseline | No minutes references; #83 adds rollback/refusal variant |
| AGN-02 published agenda delete | `DatedAgendasSystemTest#officer reviews the delete warning and deletes a published agenda` (browser) | Dialog content/focus/Escape, actual confirmed delete, later path, database state | Passed in system baseline | Preserve this unique intentional destructive path |
| AGN-07 section removal | `Admin::DatedAgendaSectionsControllerTest#cannot remove a nonempty section or the final section` (request) | Exact two refusal messages; no later persistence assertions | Passed in ordinary baseline | Strengthen surviving rows; empty section with minutes reference not tested (#83) |
| PDF-01 attested/official source | `MeetingMinutesControllerTest#ordinary members can open the attested PDF without modifying official records` plus correction/finalization variants (request) | Selected revision renderer arguments, payload/digest and record counts; renderer stub | Passed in ordinary baseline | Component selection evidence; reuse real browser/PDF coverage, do not call stub real PDF proof |
| AUTH-04 sign-out with confirmation lineage | `AccountMenuSystemTest#signing out with a pending minutes approval ends the session` and completed approval variant (browser) | Actual sign-out control, later Profile denial, confirmation session nullification, retained approval/revision | Passed in system baseline | Useful unique lineage coverage; no deletion/consolidation proposed |
| PUB-01/PUB-06 token boundaries | `WebsiteAccessAuthenticationTest` credential, revocation/conditional and cross-Post variants (request) | No-store/ETag/auth, methods, actual token/data isolation, private API denial | Passed in ordinary baseline | Retained/strengthened under #81; actual anonymous-content fault detected and restored |

## Protected-delete variants added for #82/#83

`ProtectedMeetingDeletionTest`: 24 request scenarios. Six routed targets × draft,
attested and final minutes; template copies, roll call, attendance, outcomes, empty
referenced section, surviving Meeting, source FKs, revisions/digests, attestations and
lifecycle events. Also late type/item references, whole-agenda rollback after an earlier
unreferenced item, retained AI suggestion lineage, member denials and foreign-Post IDs.
No section-deletion API exists, so that variant is explicitly unavailable.

Original candidate errors reproduced before repair (21 unhandled restriction/FK errors).
Expanded final focused execution: 24 runs / 339 assertions / no failures/errors/skips.
Isolated source-detachment fault preserved response/alert but failed the graph equality
assertion. Exact-byte restoration and clean rerun passed. No existing tests removed.

`MeetingDocumentsTest#members can distinguish and open both meeting documents on desktop
and phone`: existing member/format/provenance assertions retained; strengthened with
native type delete and real agenda dialog refusal at desktop/phone, then ordinary-member
navigation and actual PDFs. Extracted PDF text verifies saved heading, business/authority
and absence of private cues/renamed template. 2 scenarios / 127 assertions passed;
rendered screenshots inspected. PDF renderer and browser boundaries are not mocked here.

Detailed commands, failures/corrections and limits:
[review ledger](OVERNIGHT_REVIEW_2026-10-10.md). PR #85 merged after final ordinary/system
suites and successful candidate CI; actual main CI also passed. #84 remains open while
deferred file/variant review remains.

## Fresh-schema immutable-record protection (#86)

`OfficialRecordDatabaseGuardsTest`: ten direct SQL update/delete variants against final
minutes and append-only revision/attestation/event/approval rows; a separate eleven-trigger
inventory and legitimate draft update. No guard mocks or test-only installation. Each
refusal requires the immutability message and unchanged persisted attributes; unrelated
FK errors fail. Original preparation: eleven failures; fresh faithful SQL load: all
twelve tests / 45 assertions pass. All existing component/request/browser tests retained.
Endeavor triggers are inventoried here; behavioral review follows below under #88/#95.

## Speculative response during identity confirmation (#89)

`OfficialActionPrefetchTest#heading hover cannot discard the exact pending attestation
before email confirmation`: real hover, bounded test-only delayed heading response,
then actual email/code confirmation. Original layout loses pending cookie state and
fails the same missing-code-form assertion as the full-suite failure. Completed outcome
must retain the actor, exact confirmation/revision, one-use consumption and signed report.
No authentication/record mock; email uses the synthetic test job adapter. Existing stale
record, wrong-session, passkey, sign-out and approval browser variants retained. Temporary
delay callback is removed in teardown; no general multi-tab concurrency claim.

## Final occurrence context (#80)

`FinalMeetingContextTest`: HTML/API × absent/draft/reopened agenda after real attestation
and later-Meeting approval. Reloaded historical fields, signed revisions, approval/source
identity and later member reads are compared before response assertions. Separate model
and direct-SQL attempts exercise seven fields with a cached pre-final association. Positive
draft/pending-correction and dedicated website edits remain. Original routed variants
accepted mutation; the stronger graph assertion also failed on the original code.

Existing `MinutesApprovalFlowTest` retains its full handoff/correction/confirmation journey
and adds final occurrence edit refusal, member archive navigation and real final PDF reads
at desktop/phone widths. The manual two-connection probe is separately recorded; it is
not automatically discovered by Rails/CI. All earlier component and browser coverage stays.

## Member and personal-delegate reading (#77)

`ApiMeetingsApiTest`: enabled member session/bearer list/detail, independently expected
upcoming/past identities and no added grants; agenda-only list/detail/update echoes must
exclude transcript metadata and working minutes. Original code failed both variants,
showing 403 and the two actual restricted summaries.

`MemberMeetingReadParityTest`: actual handoff/attestation/reopen/pending/final lifecycle,
last attested immutable snapshot/authority, HTML comparison, privacy exclusions, unchanged
official graph, published agenda screen projection, same-token loss of office duties,
foreign/anonymous/disabled/revoked denial, and API PDF selection/failure. PDF selection uses
an explicit stub; existing `MeetingDocumentsTest` supplies real bearer JSON and actual
PDF extraction plus archive navigation and desktop/narrow review. No component/browser
assertion removed. Handbook member contract is compared to real list requests and Markdown.

Controlled working-copy substitution passes routing but fails the saved heading assertion
after reopening. Exact controller bytes restored; all five lifecycle scenarios pass again.
Commands, counts and limits are in [Member API design/evidence](../MEMBER_MEETING_API_READS.md).

## Current offices and completed retries (#78/#92)

`OfficerTurnoverAuthorityTest`: independent configured Commander/Adjutant/1st Vice duties,
same-token future/start/inclusive-end/expiry/inactive/rename, manual drafting exceptions,
honorary office, allowed/opposite official acts, and actual later-Meeting human confirmation
by both officers. Persistent graph checks precede denied-write response checks. An isolated
end-date-predicate fault changes the saved heading and fails both officer scenarios; exact
source restored. The old preset/document table mismatch is distinct from the reproduced
cached private response disclosure on unchanged main.

Existing `MinutesApprovalFlowTest` keeps all previous handoff/correction/attestation,
later approval, final occurrence refusal, member navigation and real PDF assertions; office
authority now comes from configured assignments. A new same-session browser denial proves
expired duties cannot save while ordinary member reading remains at desktop/phone widths.
Broader date-context consistency is #93, with the midnight decision pending.

## Guidance and actual delegated/website authority (#81)

`ApiGuidanceAuthorityTest` independently states seven caller duties rather than deriving
expectations from the action catalog. Both JSON and Markdown advertisements are compared
to actual member/workspace/transcript reads, drafting, publishing reads and identity-bound
official acts. Denied writes preserve full official graphs; allowed bearer acts retain the
human actor and token, consumed confirmation and unchanged grants. Session requests require
the human browser flow. An incorrect Administrator approval advertisement fails this test.

Existing `ApiMinutesApiTest` handoff/attestation keeps every previous assertion and adds
exact saved payload/digest/version/confirmation provenance and cached once-only graph
preservation. Full website access matrices remain: a missing-credential fault returns real
approved synthetic person content and fails content exclusion before 401. Correct authorized
conditional reads return empty 304, then revocation still blocks GET/HEAD/conditional reads.
Token-management tests preserve both token classes and prove absent API/UI bearer access.
Standing instructions now match authenticated website consumption and current unavailable
minutes operations; restoring the old brief fails the new contract. All faults restored
exactly; no test removal or production/live publisher handback claim.

See [design and evidence](../API_GUIDANCE_AUTHORITY_VERIFICATION.md) for focused counts,
restoration hashes and distinction from the wider deferred #84 review.

## Endeavor history SQL preservation and delegated worker provenance (#88/#95)

`EndeavorHistoryDatabaseGuardsTest`: direct SQL update/delete across guidance, events,
editions, source links and results; active run input identity/deletion, token removal or
addition to system runs; all succeeded/failed/superseded states; legitimate progress and
completion with preserved inputs. Each refusal compares persisted attributes before
requiring PG::RaiseException and the exact guard message. Minimal valid relational
fixtures use actual attestation and resolving source keys; they do not validate AI output.

Original active-token changes alter saved pending/running rows. The narrow migration
adds recorded token identity to the existing function, retaining every prior condition.
Its normal down/up restores respectively the previous/full repaired definition, and
fresh SQL load passes all 33 Endeavor/official guard cases. Disabling the edition trigger
within one test transaction changes a saved payload and fails preservation; rollback
and exact test-file restoration re-enable all guards.

Retain all existing `EndeavorHistoryTest` source/citation/coverage, publish/withdraw,
immutable callback, source change, limits, budget, reuse, policy-version and interrupted
recovery variants. Strengthen the existing recovery test with original token/event
provenance and add actual queued-token revocation refusal before the offline provider
is called. This is distinct from direct SQL protection. See
[design/evidence](../ENDEAVOR_HISTORY_DATABASE_GUARDS.md); no production/paid-provider claim.

## Configuration, entry shell and strict receipt cutoff (#96)

Real ERB/YAML parsing retains nonproduction/build defaults and independently omits each
required production key from otherwise complete synthetic inputs. A supplied-input case
checks actual database identities/host. Bypassing only queue-name refusal fails the new
variant while earlier primary/cache refusals still pass; exact config restored.

Real receipt cleanup retains the original 29-day path check/deleted 31-day row and adds
a frozen exactly-30-day row. Making the comparison inclusive deletes that row and fails
persisted preservation; exact model restored. This is cutoff/job proof, not recurrence
or an infinite idempotency guarantee; #99 separately tests and explains old-key behavior.

Retain distinct actual filter shapes, three child-process timezone boots, emblem and print
CSS source invariants, five entry-shell scenarios and twelve member/officer/admin navigation
variants. No component assertion is replaced by a browser count. Full account-menu source
review preserves keyboard/open/close/phone paths and actual sign-out with later Profile
denial, pending confirmation-session nullification and completed approval/revision survival.
No removal/consolidation is justified. See [bounded review](CONFIGURATION_AND_SHELL_REVIEW.md)
for the initial asset setup errors, corrected/clean focused runs, fault hashes and limits.

Existing calendar, minutes-item Endeavor and attestation retry tests retain every prior
assertion and add lost-authority content/record/receipt checks and permitted restored
receipts. New calendar deletion and local-midnight cases prove replay preserves valid
state-changing operations and the calendar's own date context. Routed mutation inventory
checks registration of current authority; it does not claim all action contracts are
fully reviewed. All file/variant reviews outside this slice remain deferred under #84.

Fresh pre-merge review also reproduces a cached Meeting summary after partial duty loss
while agenda editing remains authorized. The returned copy now uses the same fresh-read
visibility predicates; selected/restored grants and actual deleted-agenda receipts retain
safe content and unchanged execution/records. Passing `6045eb2` suites preceded this
additional repair; the final changed revision must be verified separately.


## Finite exact bearer retries (#99)

The existing officer API retry scenario retains same-day no-duplicate, receipt identity,
actor/completion/status and byte-identical body assertions. It now verifies saved business
fields and actual real cleanup at/beyond 30 days: exact cutoff retained; later still-retained
receipt replays until cleanup; cleaned old key creates a second distinct business row and
new completed receipt, with the original unchanged and token active. This reproduces the
existing finite guarantee, not a proposed policy change. Independent handbook expectations
fail original missing-duration prose; revised JSON/Markdown and standing instructions state
current authority/visibility and human resolution of older uncertain outcomes. Runtime and
text contracts remain distinct; concurrent/current-authority tests are retained. See
[design and evidence](../FINITE_RECEIPT_GUIDANCE.md). Remaining officer API variants are
explicitly deferred; executing the whole file alone is not complete assertion review.

## Website connection native navigation (#105)

Retain all real create/reveal-once/back/revoke and desktop/narrow overflow assertions.
Add an exact path wait/outcome after the native form POST, before querying replacement
DOM. Wrong-redirect fault fails on that outcome; exact controller restored. Local browser
passes with readable inspected created/list layouts. Two earlier Chrome154 inspector
failures remain recorded; synchronization is a bounded document-transition inference,
not a proven driver defect or a license to retry/suppress errors. The existing journey
checks a visible copy control, not clipboard contents. Full source review retains the
five website credential management/identity/foreign-scope/CSRF request scenarios and
three model digest/authority/replacement contracts; their distinct failure modes remain.
See [review and limits](WEBSITE_TOKEN_BROWSER_RELIABILITY.md).

The later actual-main38116220723 fails with the same inspector symptom in the unchanged
website-calendar native preview journey. Add its explicit preview-path assertion before
replacement-DOM queries; retain every old create/listing/attendance/no-agenda/desktop-phone
assertion. Wrong redirect fails at the path assertion, exact controller restored. Whole
six request and nine policy cases retain signed activation, current authority, replay/audit,
tampering/expiration/source changes/cross-Post scope, ETag/privacy, schedule versus approved
document protection and legacy migration contracts. Focus15/97 and browser1/21 pass.
CSRF invalid-token and incomplete whole-graph denial limits stay explicit; no clipboard
claim, safe consolidation or precise Chrome cause is established. See
[calendar review](WEBSITE_CALENDAR_BROWSER_RELIABILITY.md).


## Configured Post title update (#107)

`Admin::PositionTitlesControllerTest`'s new `update rejects a foreign Post title without
changing its authority or assignments` submits name/active/membership edits through the
actual route. Original global lookup changes stored foreign fields and fails preservation
before 404; configured association lookup preserves both Post graphs, refuses and permits
later legitimate own-title save. All old active/membership/order/settings variants stay.

New browser `foreign position submission preserves saved authority and own controls still
work` submits a foreign identity through a native form to inspect standard 404, then real
ordinary Turbo deactivate/activate/grant/remove controls at 1400/390px, checking stored
fields and foreign grants/assignments. Initial Turbo/static-page and test-debug-page
assumptions failed and are documented; exception details are restored and :rescuable
policy is retained. No new inline Turbo error behavior is claimed. See
[scope and source review](POSITION_TITLE_UPDATE_SCOPE.md) for distinct retained officer,
account and permission components; serial last-admin tests are not concurrency proof.


## Passkey cryptographic refusal and later recovery (#104)

Retain every option/verification-argument, disabled/unknown, rate-limit, own/foreign
credential, enrollment freshness/session/purpose and reauthentication assertion.
Strengthen generic refusals with unchanged stored credential/session graph before status.
New `real passkey authentication rejects unverified or wrong challenge assertions and
recovers` registers a real FakeClient key, starts fresh cookie-free browsers, submits
missing-verification and signed wrong-challenge assertions, preserves saved state and
then proves new verified owner sessions/counter/use timestamps plus later Profile access.
Relaxed authentication verification fails stored metadata; exact source restoration
returns focused checks to green. No cryptography/policy change or test deletion.

All eleven neighboring auth files are source/assertion reviewed with their distinct
failure modes and limitations in [passkey review](PASSKEY_REFUSAL_REVIEW.md). Actual
phone sign-in/sign-out, continued enrollment with virtual authenticator and token
reveal/back/revoke journeys are separately executed; neither source review nor a test
count establishes external delivery or clipboard content. Official-action confirmation
and invitation files remain outside this bounded full-file review.


## Empty National roster refusal and actual upload recovery (#111)

Original suspected nil-header defect is disproved by actual locked CSV::Table behavior
and clean parser/attached empty-file route checks; there is no application repair.
The original `missing required headers is fatal` retains partial-header assertions and
adds empty/BOM-only inputs. New `empty uploaded CSV preserves people and sign in then a
valid upload succeeds` verifies the actual saved failed import, unchanged people/users/
grants/earlier completed history, rendered error and subsequent successful upload with
same member identity and unchanged private login address. Bypassing only empty-header
validation fails both invalid-result and stored failed-import outcomes; exact restoration
returns all roster checks to green.

New real browser `empty file upload preserves members and a later valid upload works`
uses actual file controls, rendered refusal and “Import another roster” before valid
recovery. Old named account/deceased-warning journey and all thirty importer/thirty
original upload controller/seven parser/seven model cases stay. Desktop/390 failed and
completed layouts inspected; global header-problem heading is recorded as an existing
incidental wording limit. Full source/assertion contracts, fault hash, commands and
execution boundaries are in [empty-roster review](EMPTY_ROSTER_INPUT.md). No consolidation,
National source copy, broad rescue or concurrency claim.


## Overlapping last-administrator changes (#112)

`overlapping administrator grant removals preserve one enabled administrator` uses real
independent signed-in HTML sessions/connections and PostgreSQL row locks/wait state to
schedule the actual write window. Original source leaves zero stored eligible admins and
fails before response checks. Shared User transaction/ordered target+admin locks preserve
one settings administrator; saved person/account/session identity and unrelated grants
remain, one truthful refusal and one permitted message render, and later admin reads
match saved authority. Separate manual-disable and roster-control overlap cases protect
mixed existing routes. Observer SQL is uncached and all waits/queries are bounded;
initial cached-observer harness timeout is recorded separately from the real defect.

All five serial grant/filter/automatic-role tests and thirty User component cases remain.
New browser `last administrator refusal preserves permissions and later permitted handoff
works` exercises actual controls, unchanged refused graph at1400/390 and successor handoff
with later old/new authority navigation. It does not establish browser concurrency.
See [design and evidence](LAST_ADMINISTRATOR_CONCURRENCY.md). Local-panel National
provenance mismatch is separately #115; explicit Post-date policy remains #93.


## Personal token secret refusal and retained components (#102)

The active actual-public-ID/guaranteed-different-hex secret case now checks saved token
metadata before refusal in both the existing model denial test and existing invalid-bearer/
valid-cookie request. The cookie first reads fixed private Endeavor text; the wrong bearer
must neither record use nor expose that text. All old malformed/expiry/revocation/disabled
assertions remain. Removing only `valid_secret` fails each saved-state check; exact model
bytes restored in finally and clean behavior passes. Whole own/admin credential request,
website credential model and real token browser tests remain separate retained contracts.
Current integrated focus43/286 passes on877c18e; this scoped API case does not certify every
mutation in OfficerApiTest. Details: [personal credential review](PERSONAL_TOKEN_AUTHENTICATION_REVIEW.md).

## Restricted transcript receipts, retry errors and offline provider failure (#79/#84)

Preserve the existing cookie create/explicit-read/seed and blank-input cases. New real
bearer source/replay for both retention choices checks actual durable receipt attributes
for fixed raw-source sentinels before status/key absence; duplicate/invalid-policy errors
preserve source/minutes and retain safe receipts. Explicit authorized reads create no
receipts; current grant loss refuses both reads and completed replay. Existing HTML
error case now includes nonblank source with invalid retention: safe error summary,
no insertion, unchanged minutes and intentionally preserved authorized retry textarea.

Retain all nine offline provider cases; strengthen supplied server/quota/configuration
error messages with a proven raw-source fixture. New actual-adapter/service path preserves
minutes/source and stores safe failure category/request ID without echoed source. Real
browser1/33 follows invalid submission, valid recovery, restricted reader, permission loss,
Profile and actual sign-out/protected denial at desktop/phone widths. Four controlled
fault executions catch durable receipt/HTML summary/provider message/failed-run leaks,
finally restore exact bytes, clean focus54/531 passes. The thirty-day scheduling decision
and actual deletion remain #79/PR#98; this is independent privacy evidence, not purge
completion. See [scope and evidence](TRANSCRIPT_SOURCE_PRIVACY_REVIEW.md).

## Real copied token bytes and permission denial (#121)

Both existing personal/Post-website journeys keep their distinct authority, issuance,
reveal-once/back and revocation assertions. Shared browser support sets a fixed stale
synthetic clipboard value, performs the real copy and reads exact actual copied bytes.
Actual denied-write permission then produces the manual fallback with source focus and
full exact selection. Stored credential attributes stay unchanged. Omitting only the
application clipboard write preserves its success label yet fails both byte assertions;
finally restores exact JS. Browser permissions reset in nested ensure; no stubbed
clipboard, broad rescue, skip or consolidation. See [design and evidence](TOKEN_CLIPBOARD_REVIEW.md).

## Optional passkey invitation continuity (#117)

Keep the existing Dashboard positive dismissal detector and anonymous request component.
The former now proves a visible invitation and unchanged nonempty person/account/grant/
passkey/session graph, later own Profile/home and a distinct fresh authenticated session.
The new real-browser journey supplies actual email sign-in, dismissal, Profile/home,
sign-out/protected refusal and fresh invitation while other-person sessions remain.
All twenty Dashboard and six Profile cases remain; AuthenticationEntry and AccountMenu
retain distinct real authentication/keyboard/official-confirmation contracts. Omitting
only the dismissal flag fails the retained card-absence assertion; exact controller
restored. Frozen test clocks avoid legitimate last_seen touches, without app changes.
See [design and evidence](PASSKEY_INVITATION_REVIEW.md); no safe consolidation established.
## Roster email identity and offline audience boundaries (#108/#109)

Existing five email-review requests keep every old assertion and now inspect independently
expected review address/decision/time, actual login, unchanged National person/access/
nonempty target-and-foreign grants/session graph and later own Profile. Invalid and
anonymous writes preserve every stored field; a same-alert invalid write fault fails
saved identity. User keep/remind components retain all prior predicates and add actual
metadata. New real browser checks invalid form plus update/keep/remind, same-session
suppression, sign-out/protected denial and fresh-sign-in re-prompt at desktop/390px.

The six sync service cases retain every old result. Superseded input now requires zero
provider opens/payloads and intact source/requester before failed status; dispatch-before-
start fault fails that assertion. A separately named two-contact case requires both
fixed payloads, exact failure identity/counts/timestamps/pacing; break-after-first fault
fails on missing second payload. Exact service/controller bytes restored. Audience,
fake HTTP and admin components retain distinct unchanged contracts. New actual offline
service/browser read navigates source/partial results/preview and loses settings access
while ordinary Profile remains. No provider opt-out state or Solid Queue dispatch claim.
Details: [email identity](ROSTER_EMAIL_IDENTITY_REVIEW.md),
[offline audience](OFFLINE_ROSTER_SYNC_REVIEW.md). No test deletion/consolidation.


## Whole-source directory, roster and privileged-confirmation variants

The [directory/roster review](DIRECTORY_AND_ROSTER_SOURCE_REVIEW.md) records separate
HTML index/detail, private bulk/summary JSON, Person/User representation, own Profile,
menu destinations, membership report, roster transactions/preview/source and offline
HTTP/audience/service contracts. The [confirmation review](PRIVILEGED_CONFIRMATION_SOURCE_REVIEW.md)
retains purpose/session/code, link GET versus consuming POST, changed-text refusal,
stubbed passkey orchestration, sign-out provenance and independent invitation boundaries.
[Exact case names and pinned source lines](SOURCE_REVIEW_CASES.md) associate each retained
case with its reviewed assertions. Actual-main15ce51b all-four CI executes those files;
that unchanged-suite execution does not demonstrate a representative fault for every
assertion. Separately completed #108/#109/#111/#112 have their own runtime/fault evidence;
#115/#117 and #93 decisions remain open. No safe test consolidation was established.


## Independent source size and uploaded UTF-8 reading (#124)

All seven original transcript components remain. Old oversized input followed the app
constant; a raised-limit control leaves it passing. Fixed five-megabyte plus one input
and a separate exact-byte multibyte case now detect the same raised-limit fault in both
pasted/upload paths. Refusals preserve source/blob/attachment and identity; later exact-
size retry saves actual bytes, digest, creator and retention selection. Uploaded Unicode
originally raises on binary-to-UTF-8 transcoding after raw storage agrees. One-line copy/
encoding interpretation preserves bytes and existing BOM/CRLF normalization; small
original reproduction fails, repaired component/request/provider neighbors pass62/674.
Real uploaded-file browser variant reads accented source at1400/390, then loses source
authority while own Profile works and source/minutes stay intact. Both existing privacy
and new upload journeys pass2/167; no claim about automatic purge/provider completion.
See [design and exact evidence](TRANSCRIPT_SOURCE_INPUT_REVIEW.md). No test removal.

## Whole-source minutes editing, review and worker variants

Thirteen files/88 exact cases are separately indexed in
[the pinned minutes case index](MINUTES_SOURCE_CASES.md) and mapped in
[the source review](MINUTES_REVIEW_SOURCE_REVIEW.md): structured snapshot/digest/
validation, manual editor mutations, individual suggestions and attendance, correction
requests, optional handoff/attestation/locking, durable ledger/retry, numbered source/
prompt instructions and offline background job chain. Actual-main5c54e39/all-four CI
executes unchanged cases; source assertions and runtime/fault detection stay separate.
Real approval browser and disclosure-only browser keep independent purposes. #128
tracks initial rejected-enqueue mismatch before repair; #93/#79 decisions remain open.
The every-editor test covers two surfaces, and a named same-body test only rejects a
future meeting here. No blanket matrix, redundant-test or provider acceptance claim.

The whole API minutes10 file is now separately indexed/reviewed: actual bearer source
privacy, structured mutations, exact official provenance/replay and grant-loss graph
remain distinct from cookie requests/fake PDF/manually attested fixtures. #131 retains
existing detached Session refusal and records missing direct ten-minute/atomic consumption
proof before component edits; no demonstrated app defect or consolidation is claimed.

Whole Generate30 review completes that component's source reading and brings this
minutes index to14 files/118 exact cases. Retain distinct structured validation,
human review, provenance, same-ID polling, deadline/cancellation, source-change and
terminal-output assertions. Source-only review is separate from the previously proved
SDK privacy fault and actual CI execution; no fake-provider live acceptance claim.

Minutes-to-Endeavor whole request12/browser3 review brings the index to16 files/133
exact cases. Preserve manual form/atomic identity/grants/recovery/staleness/scope and
original AI payload/result provenance detectors plus real keyboard/source-evidence/
human editing/linking/dismissal journeys. Governing manual/AI confirmation policy,
synthetic providers and artificial locked-state limits are recorded in the source review.

Agenda catalog4 files/47 cases source-reviewed: actual requests, model normalization/
atomic ordering/soft removal, concrete Legion seed/local-edit continuity and browser
drag/arrow/modal/focus remain distinct. Coupled seed-definition transport is separate
from fixed counts/wording/order; identity-only removal proof is separate from full
historical body/PDF preservation. [Review and pins](AGENDA_CATALOG_SOURCE_REVIEW.md).
All tests remain; no new runtime fault or safe consolidation is claimed.

Meeting body/type/template model4 files/25 cases extend that index to8 files/72.
Keep scalar location fallback, provenance/uniqueness/unused deletion/order, default/
normalized/nonempty sections and rich/private copied wording/local overrides/source
scope distinct from protected linked-type, dated/minutes snapshots and real PDF/authority.
Combined source slice24 files/205 cases; no code/test edits or consolidation.

Template seeder19 extends catalog/template index to9 files/91 cases and the combined
source slice to25 files/224. Preserve fixed concrete Legion titles/section occupancy,
local rich edits/active/order, referenced dated title/section, repeat/default/second-Post
and reset detectors. Custom-row existence and title-only snapshots have explicit limits.

Whole `test/controllers/api/idempotency_concurrency_test.rb` is separately read at
b965cf76 (one case and all setup/teardown): [concurrent first uses serialize and perform one mutation](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/api/idempotency_concurrency_test.rb#L24).
Two independent actual bearer request sessions start from a shared queue gate after
warmup; both return201 with identical bodies, one fixed-title Endeavor and one exact-key
receipt. Transactions are disabled for cross-connection visibility and synthetic rows
are cleaned in teardown. Keep this actual concurrent-request detector beside current-
authority/replay/receipt cleanup contracts. The gate releases both callers but does not
prove a held lock or separate backend IDs; no revocation-race matrix, real human token
issuance or new fault is established. One full-source addition brings this branch to
26 reviewed files/225 pinned or directly linked cases; no app/test change or consolidation.

## Rejected initial minutes enqueue and recovery (#128)

Actual Active Job before_enqueue abort reaches all four routed create/retry paths.
Original false-result method errors leave pending runs/nil failure metadata while source,
manual minutes and earlier run rows remain intact. Three existing guard corrections
record durable failed queue_error/completion without a broad rescue. Four new request
variants read saved identity/link/graph before response, then restore actual enqueue and
retain both failures. Real browser checks existing failure/manual escape, rejected retry,
restored queued state, grant-loss status/protected denial and later own Profile. Whole9
original draft API cases are retained/indexed with distinct direct state/single-attendance
limits. [Design and evidence](MINUTES_ENQUEUE_RECOVERY_REVIEW.md); queued font gap#130
and actual provider acceptance are separate. No test deletion, app authority or policy change.

## Whole PDF component source slice (#84)

Seven complete files /40 exact cases at b965cf76 distinguish filename/signature/transport,
loopback/CSP/organization/filter boundaries, real immutable officer/member revisions and
actual native resource blocking. Read every helper/fixture/assertion; exact names, lines
and blobs pinned in [PDF_COMPONENT_SOURCE_CASES.md](PDF_COMPONENT_SOURCE_CASES.md).
[Located outcomes and limits](PDF_COMPONENT_SOURCE_REVIEW.md) preserve fake transport
versus real bytes, source HTML versus repeated page folios, filtered hidden content,
status-only refusals and optional artifacts. All tests remain; no safe deletion or
consolidation established. Recorded main CI is separate from source/fault evidence.

## Whole template/dated-agenda component source slice (#84)

Six complete files /39 cases at b965cf76 retain actual template copy/removal/error
classification/section routes, historical rich dated snapshots, approved section locks,
meeting-date roll-call refresh/snapshot, conservative legacy wording separation and
reversible UTC-wall migration. Exact names/lines/blobs in
[DATED_AGENDA_COMPONENT_SOURCE_CASES.md](DATED_AGENDA_COMPONENT_SOURCE_CASES.md),
[located actions/assertions and limits](DATED_AGENDA_COMPONENT_SOURCE_REVIEW.md).
Keep distinct seeded/local/error/model/route/history cases; no safe consolidation or
test edit is established. Source reading, recorded execution and existing fault proof
remain separate. No production backfill/migration or new authority date choice.

Four additional complete dated-agenda files /40 cases extend that slice to10/79.
Real Endeavor picker/copy/duplicate/lock, independent rich catalog/template/Endeavor
snapshots, stale locks/reorder/transition identity and published member HTML/PDF route
selection remain distinct. Fixed exact case/blob pins and implementation-coupled lock
increment, inactive-fixture/status-only/fake-renderer and unlinked-destruction limits
are recorded in the same source review. All assertions remain; no runtime or cleanup
claim follows from source reading alone.

## Whole publication component source slice (#84)

Five complete files /26 exact cases at b965cf76 and the shared fictional publication
fixtures separate real website bearer/conditional snapshots, human consent/withdrawal,
source callbacks, native portrait/browser controls and actual observed PG held-lock
commit orders. [Exact case/blob pins](PUBLICATION_COMPONENT_SOURCE_CASES.md),
[located outcomes and limits](PUBLICATION_COMPONENT_SOURCE_REVIEW.md) distinguish
inactive legacy editorial state from automatic activation, status-only/exception-only
parts, direct session/token fixtures and unverified live publishing. All retained;
source reading and recorded CI remain separate from representative defect evidence.

## Whole installation/access/offline adapter source slice (#84)

Eight complete files /39 cases at b965cf76 retain real initial/partial/recovery setup,
explicit Legion preset/technical scope, officer hub visibility/roster age labels,
valid-CSRF direct-upload denial, print identity and offline mail/provider/real SDK
serialization. [Exact names/lines/blobs](INSTALLATION_ADAPTER_SOURCE_CASES.md) and
[located outcomes and limits](INSTALLATION_ADAPTER_SOURCE_REVIEW.md) separate unsaved
validation, status/count-only portions, direct session fixtures and external acceptance.
No tests/app changed or safe consolidation demonstrated. Source review never proves
live delivery/paid AI or substitutes for #115/#79/#93 follow-up evidence/decisions.

## Whole continuing Post work source slice (#84)

Six complete files /37 cases at b965cf76 retain optional task dates/completion/reopen,
append-only human updates, current/historical member continuity and exact related
immutable passage/outcome reads. [Exact names/lines/blobs](ENDEAVOR_COMPONENT_SOURCE_CASES.md),
[located action/outcome and limits](ENDEAVOR_COMPONENT_SOURCE_REVIEW.md) separate real
handoff/attestation and saved rows from unsaved validation, status-only stale errors,
manifest/config fixture coupling and fake history editions. No app/test edit or safe
consolidation; existing #88/#95 source/SQL/provider fault proof remains independent.

## Whole calendar component source slice (#84)

Seven complete files /52 exact cases at b965cf76 retain real manager/member event actions,
protected/stale/foreign deletion, filters/keyboard/Post-calendar dates, responsive details
and actual private server/native print delivery. [Exact names/lines/blobs](CALENDAR_COMPONENT_SOURCE_CASES.md),
[located outcomes and limits](CALENDAR_COMPONENT_SOURCE_REVIEW.md) distinguish fixed parsed
page geometry and native state restoration from fake PDF wiring, partial refusal graphs,
optional visual captures and unverified failure-path emulation cleanup. All assertions
remain; no safe consolidation or blanket fault/runtime proof follows from source reading.

Official confirmation lifetime/atomicity (#131) adds direct fixed-ten-minute factory,
before/after expiry, wrong live identity/session, consumed reuse and real persisted
attestation-phase rollback/recovery components. Full saved confirmation/minutes/revision/
attestation/event graph remains unchanged on refusal or rollback. Expiry fault2/2/2
detects both refusals; exact source restoration leads to47/658 neighbors and3/131
real approval browsers clean. [Design and evidence](OFFICIAL_CONFIRMATION_CONTRACTS.md).
Keep the separate existing detached Session, provenance, request and browser assertions.

Queued progress readability (#130) extends that same browser recovery journey with
independent fixed13px labels/14px supporting text/16px body and action floors, requiring
each actual selector at1400/390. Original11px badge failure2/68/1 detects the gap;
Five font values produce2/128 clean. The actual no-JavaScript fallback then catches
its original13px body below16px:2/128/1 failure, seed23385. Its sixth font correction
and actual script-disable/ensure-restore variant pass2/139, seed59695; the complete
instruction and existing progression/actions were inspected at1400/390 without overflow.
All previous assertions remain. [Design and evidence](MINUTES_MONITOR_TYPE_FLOORS.md).

Real browser PDF delivery (#134) keeps every existing approval/member/document/agenda
byte/content/identity/immutable graph assertion. Scoped35-second PDF async helper
matches the30-second renderer budget with margin and asserts ordinary wait restores.
Original3-second real-fetch delay1/62/1error becomes1/95 clean; wrong HTML reaches
the existing readable-String assertion1/64/1 with a temporary message result, then
exact scripts restore. Clean neighbors16/437 and final approval3/133 retain actual
PDF/refusal/private resource boundaries. [Evidence](PDF_BROWSER_WAIT_CONTRACT.md).
No general timeout increase, retries, skips, app or authority changes.

## Whole Meeting occurrence/member/template-management source slice (#84)

Seven complete files /66 exact cases at95a38a3 retain durable Meeting/body venue
snapshots, honest member agenda/minutes states, actual rich immutable correction
presentation and scoped private API echoes, guided officer occurrence and real native
Turbo/template controls. [Exact names/lines/blobs](MEETING_OCCURRENCE_SOURCE_CASES.md),
[located outcomes and limits](MEETING_OCCURRENCE_SOURCE_REVIEW.md) preserve distinct
real attestation/content proof versus fake renderer, direct confirmation, partial denial
graph and relative-order tests. All kept; no safe consolidation or universal fault proof.

## Whole dated-agenda workspace/member-document source slice (#84)

Five complete files /61 exact cases at95a38a3 retain scoped discussion/section/roll-call
writes, human agenda transitions, saved local snapshots and private notes, actual
protected deletion and native parsed member HTML/bearer PDF content at desktop/narrow.
[Exact names/lines/blobs](DATED_AGENDA_WORKSPACE_SOURCE_CASES.md),
[located outcomes and limits](DATED_AGENDA_WORKSPACE_SOURCE_REVIEW.md) preserve concrete
source/action outcomes versus prefix-only PDF, partial graphs, vacuous Array.every and
fixture-coupled styling. Keep every assertion; no safe consolidation or blanket fault proof.

## Whole remaining delegated API component source slice (#84)

Four complete files /82 exact cases at95a38a3 retain scoped private data, exact real
bearer identity/receipt lifetimes, local agenda lineage/order/roll-call, calendar public
projection/date/management and actual editorial portrait/audit/public consumer removal.
[Exact names/lines/blobs](DELEGATED_COMPONENT_SOURCE_CASES.md),
[located outcomes and limits](DELEGATED_COMPONENT_SOURCE_REVIEW.md) distinguish partial
saved graphs, direct settings fixtures, application-coupled allowlists and the original
eight-mutation retry title (#139). Every assertion remains; no universal fault/safe
consolidation/live-policy proof follows from source reading.

## Failed browser state and original retry-name cleanup (#137/#139)

Actual controlled failed print case/normal teardown/session reset leaves print media
for the next case. A scoped class teardown reset restores real later screen navigation;
temporary failure/order removed and all assertions in the original three calendar cases retained. The
renamed API case retains all eight original agenda/Endeavor actions and every body/
helper assertion; real narrowly duplicated updates reach its existing saved-count
failure. [Exact design, restoration and clean neighbors](CALENDAR_PRINT_STATE_CLEANUP.md)
separate injected failures from application incidents and universal retry claims.
