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
| PUB-01/PUB-06 token boundaries | `WebsiteAccessAuthenticationTest` credential, revocation/conditional and cross-Post variants (request) | No-store/ETag/auth, methods, actual token/data isolation, private API denial | Passed in ordinary baseline | Reuse for #81; credential fault probe remains pending |

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
Endeavor triggers are inventoried here; their behavior remains a separate review slice.
