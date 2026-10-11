# Minutes lifecycle, editing and background source review

Bounded #84 source/assertion review at5c54e39, October11,2026. Governing
MINUTES_APPROVAL_AND_ATTESTATION.md supplies optional Commander handoff, editable
Adjutant review, immutable attestation, later meeting approval, pending corrected text
and atomic final locking. MINUTES_LIFECYCLE.md distinguishes restricted source, AI
suggestions and human records. Current approval documentation supersedes older provider
configuration prose in the lifecycle history. #77/#78/#79/#80/#81 and their completed
guard/authority slices retain separate runtime proof; #93/#79 decisions stay open.

Read all cases, fixtures, helpers and assertions in the fourteen files below. Exact names,
source SHA, file blobs and lines are in [MINUTES_SOURCE_CASES.md](MINUTES_SOURCE_CASES.md).
This is source-only work: no app/test edits, new execution, faults, test deletions or
consolidation. Actual-main5c54e39 CI38120256442 executes the unchanged components:
PostgreSQL17.11 ordinary1292/11778 then system72/1506, all four jobs pass. That recorded
execution is separate from demonstration that each assertion catches a regression.

## Retained distinctions and actual limits

| Exact file / cases | Starting state, action, persisted and visible outcomes, subsequent behavior / limits |
| --- | --- |
| `test/controllers/admin/minutes_corrections_controller_test.rb` /5 | Existing attested copy, actual reopening prepare/complete and saved reopened event/reason; Commander without attestation opens reopening; exact attested copy records later corrected approval; ordinary draft handoff wording remains; pending corrections require adopted wording before confirmation creation. Direct confirmed_at setup bypasses real identity; complete immutable graph and every failed payload/session variant are not asserted here. |
| `test/controllers/admin/minutes_draft_runs_controller_test.rb` /14 | Actual intake disclosure/source/configured model; POST prepares pending run and enqueues; pending HTML/JSON no-store monitor without percentage; Endeavor proposal and individual source-linked cards; preselected attendance/vacancy and bounded human changed/used states; one actual suggestion changes its field; Turbo card/counter response; unknown-result refusal before outcomes; known-result/full-record/roster controls; verified mover/unidentified seconder preserve heard payload; edit-before-using resolver; viewer cannot open initiation/review. Request/session setup and synthetic succeeded runs do not prove browser polling completion or provider acceptance. Denials do not save every graph. |
| `test/controllers/admin/minutes_editor_controller_test.rb` /10 | Manual heading independent of Meeting; complete workspace/control/organize rendering; viewer reads but cannot edit; real section create/rename/order/delete and nonempty refusal; item create/reparent/order/delete; motion participant/name/result updates and outcome ordering/deletion; human result choices/roster search; explicit other disposition; attendance present versus unknown. The case named every editor surface actually checks section-new GET and item-create POST against an artificially attested status, not every mutation. Keep those useful assertions and separate SQL guards. |
| `test/controllers/admin/jobs_controller_test.rb` /6 | Durable failed/succeeded run cards and worker-health unavailable; attention/discard filters; real linked retry enqueue and original failed predicate; active retry reuse with no enqueue/count change; discard/restore provenance without deletion; unauthorized console denial. Existing successful enqueue and predicates do not establish initial rejected-enqueue recovery or whole prior-run preservation. |
| `test/controllers/admin/meeting_minutes_controller_test.rb` /9 | Past Meeting scaffold and later workspace; internal viewer reads but cannot create; separately configured Commander/Adjutant read without edit; fake PDF renderer checks inline response and actual selected minutes, distinct from real PDF contents; anonymous/unrelated refusal; future creation count/absence; actual pending confirmation binds user/session/action; editable handed-off heading differs from saved revision; unknown attendance keeps next-step explanation. Midday Date.current fixtures do not decide #93. |
| `test/models/meeting_minutes_test.rb` /18 | Fixed legacy JSON digest protects serializer compatibility; past scaffold/no agenda; agenda wording/hidden private cue/attendance snapshots; actual catalog/template updates and source-link deletion preserve payload; draft agenda heading selection; duplicate/future refusal; foreign source/Endeavor validation; explicit unknown outcome facts; Meeting deletion restriction; delegated/external approval/attestation provenance; dual-duty attestation; reopening/revision/member copy/later corrected approval; immutable approval/minutes and deletion refusal; future later-meeting refusal before consumption; direct Adjutant/no invented Commander; changed handoff retains both payloads; stale/missing-attestation refusal; pending decision/final corrected payload/provenance/lock. The earlier snapshot case only assigns later source body in memory, while the separate catalog/template case actually saves mutations. The later-meeting test rejects future date; its title alone does not prove all wrong-body/earlier-meeting cases. |
| `test/models/minutes_draft_run_test.rb` /1 | Actual original and other-Meeting source fixtures; cross-minutes retry validation and incomplete discard actor/time validation. Unsaved invalid objects test validation, not full routed retry/persistence/concurrency or symmetric provenance variants. |
| `test/services/minutes_drafting/source_document_test.rb` /3 | Exact stable numbered lines/excerpt; long punctuation passage splits and stays within configured length; oversized unspaced input reassembles without content loss and correct chunk lengths. Configured internal length expectations are not an independent product byte-size limit. Empty/invalid excerpt variants are not located here. |
| `test/services/minutes_drafting/prompt_test.rb` /2 | Concrete instruction text retains agenda-subject routing, exact Endeavor lookup/source citation, absent-member detail, privacy exceptions and uncertain-identity constraints. These are prompt-contract detectors, not evidence the external model obeys them. Offline Generate/provider validation remains independent. |
| `test/services/minutes_drafting/generate_test.rb` /30 | Offline synchronous and background providers retain exact source/model/token provenance, independently reviewed suggestions and unchanged manual minutes; new/existing Endeavor routing, stale/foreign identities, rationale/length and source citation validation; reviewed/dismissed/manual removal and additional-item outcomes; superseded prompt/no submission and terminal redelivery; actual SDK failure keeps safe metadata and original minutes/source. Background cases assert one submission/same response ID, pending retrieval, retryable timeout, initial/late timeout and cancellation, terminal retrieval failure, invalid completed output with preserved provider IDs, unknown running ID without resubmission, source changes before/during retrieval, released minutes and duplicate completion without suggestions. Component assertions vary: some validate only the exception/category, while others preserve saved content, counts and provenance. Configurable deadline tests use the application timeout constant; fake provider counters are independent of live SDK acceptance, real queue dispatch and current routed authority. Keep all thirty cases and their distinct validation/polling/cancellation/provenance detectors. |
| `test/jobs/minutes_draft_generation_job_test.rb` /6 | Stubbed service delegation; unexpected worker error becomes safe failed state and rethrows; fixed-time pending-response polling enqueue; succeeded no next poll; actual job chain plus offline provider submits once/retrieves same ID twice/completes without official status; rejected polling enqueue retains failed queue_error/response ID/completion. Shared method replacement/set restoration uses ensure. This is the test queue adapter, not real Solid Queue worker dispatch or paid provider acceptance. |
| `test/system/minutes_background_drafting_test.rb` /1 | Real magic-link browser disclosure/model/manual escape/submit control at1400/390 with overflow and font floors. It never submits, polls or applies a completed suggestion. Retain it for independent disclosure/readability detection; do not treat the case name as provider/background completion proof. |
| `test/system/minutes_approval_flow_test.rb` /3 | Real configured officers without manual grants: code-confirmed handoff, editable Adjutant review, attested member copy, later pending-correction decision, corrected final human lock; phone progression; saved original Meeting/revision refuse rewrite; ordinary member later HTML and actual fetched/rendered PDF contains final title/status. Direct Adjutant uses link GET then actual POST, and same browser loses officer edit after assignment expiry while member navigation/session continues. Real email is synthetic test delivery; same-session expiry proof does not decide inconsistent near-midnight date contexts (#93). |
| `test/controllers/api/minutes_api_test.rb` /10 | Actual restricted source/create/explicit read/scaffold/later safe Meeting projection; both-policy real bearer receipts/error/replay/no-store/source and grant-loss preservation; internal viewer reads but cannot heading/source mutate; structured sections/items/outcomes/reorder/attendance/later content; locked-state section refusal and fake PDF delivery; bearer scaffold exact retry; member draft denial; independently configured Commander/Adjutant read without draft/source mutation; separate bearer handoff/attestation fixed snapshot/version/digest/token/confirmation/event and exact replay graph; editable Adjutant handoff/direct attestation/current-authority loss/restored same receipt. Synthetic manually attested status and fake PDF are distinct from actual saved human revision/rendered PDF; expected snapshot uses app revision_payload and does not alone prove every independent field; real content/digest neighbors remain. All cases retained. |

Controllers inspected against those requests include actual reopening/membership approval,
draft scope/editability, draft creation/status, Jobs retry and API create/retry enqueue.
The monitor uses authenticated no-store fetch and Turbo replacement on terminal status.
The whole Generate file is now reviewed and retained; its offline provider evidence
remains distinct from actual queue/provider acceptance. Other API components retain
their current scoped review status. Revisions,
SQL protections, member projection and genuine passkey authentication are independent
components; neither the request counts nor the browser journey makes them redundant.

## Material bounded follow-up

Locked Active Job8.1.4 documents and implements perform_later returning a job or false.
The worker checks both for a rejected polling enqueue; HTML initial creation, Jobs retry
and API shared create/retry helper call successfully_enqueued? directly. #128 records
this discrepancy, original routed reproduction, durable failed run/unchanged minutes/
source/prior attempt and restored later enqueue before the smallest repair. No production
incident is established by source. Initial false handling and browser monitor completion
remain distinct from the six retained job components and disclosure-only browser case.

The expanded whole API10 review preserves exact bearer provenance/replay/current-
authority checks. SessionTest's existing detached-session refusal/consumption block and
completed approval preservation stay independent. Governing ten-minute expiry and
atomic official consumption lack an explicit direct expiry detector in the located
components; #131 records bounded model/session/rollback verification and restored fault
before edits. No source defect or whole TTL/session/payload matrix is claimed. Other
official-action components remain to review without duplicate coverage.
No safe consolidation is established. Preserve every assertion and the source-only
execution/fault distinction. No production, real member-data copy or paid AI occurred.
