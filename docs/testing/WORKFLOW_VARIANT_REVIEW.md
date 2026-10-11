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

Existing calendar, minutes-item Endeavor and attestation retry tests retain every prior
assertion and add lost-authority content/record/receipt checks and permitted restored
receipts. New calendar deletion and local-midnight cases prove replay preserves valid
state-changing operations and the calendar's own date context. Routed mutation inventory
checks registration of current authority; it does not claim all action contracts are
fully reviewed. All file/variant reviews outside this slice remain deferred under #84.
