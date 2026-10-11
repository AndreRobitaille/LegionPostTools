# Transcript retention lifecycle — approved implementation design

Design for #79, begun October 10 and approved October 11, 2026. The implemented
repair follows the contract below. Local synthetic evidence and exact-revision CI
qualify the code; they do not establish production scheduling, storage or backup erasure.
Current minutes lifecycle and approval/attestation policy govern.

## Approved recovery clock (October 11, 2026)

Approval with pending corrections records the later Meeting's real decision before
the corrected text receives final Adjutant attestation and becomes locked. Andre chose
that final corrected attestation as the start of the 30-day recovery window. Source
remains available while authorized corrections are pending. Ordinary approval starts
at final membership approval. The prior meeting decision retains its original timestamp;
no official row or event is rewritten to move the clock. The implementation below is
authorized, but is not a production deletion claim.

## Original source evidence (historical)

Source `0a5686a92bc0203085497fc4f3e75a8c6d8b5215` (local source review, not production).
The transcript model/services, drafting generator and recurrence are unchanged since
the original `6045eb2` review:

- `MeetingTranscript` stores pasted content or one Active Storage text attachment,
  retention policy, source digest/metadata and purge fields. `purged_at` blocks reads,
  and current validation requires a human `purged_by` for that state.
- Only `MeetingTranscripts::Create` exists in that service directory. No transcript
  scheduling/purge job or recurrence was found. `config/recurring.yml` schedules queue
  cleanup, agent receipt cleanup and Endeavor reconciliation.
- Existing `MeetingTranscriptTest` checks normalization, original uploaded bytes/digest,
  exactly-one-source validation, foreign scope, no replacement, and an already-purged
  record's provenance/read refusal. All are useful and remain; none proves scheduling
  or actual file deletion through the promised lifecycle.
- `MinutesDrafting::Generate` reads the current transcript for preparation/generation and
  refuses an unavailable source before calling its provider. Runs retain source digests
  and line counts; suggestion excerpts read the transcript dynamically and become nil
  after purge. No full transcript snapshot was located in these persisted run fields.
  Provider output/proposals and already-reviewed narrative are distinct retained records,
  not proof that the underlying transcript still exists.

## Implementation contract

The immutable final approval and its revision's attestation supply the durable clock:
the later of approval.recorded_at and attestation.attested_at, only for locked final
minutes. This is ordinary final approval or final corrected attestation, respectively.
Compute the due time as thirty full 24-hour periods after that instant, consistently
across request zones and daylight-saving changes. A second mutable schedule timestamp
is unnecessary. Do not move an old finalization date to the eventual deployment date.

Use one hourly background recurrence, a bounded batch of at most 500 due sources, and a
single idempotent service. Query only final, delete-after-acceptance, unpurged sources;
recheck policy, source state and finalization under the transcript lock. Existing final
records and sources attached later participate from their actual finalization time.
Delayed execution removes a still-due source on a later run; repeated execution preserves
completion metadata. Retain-restricted never enters automatic purge. A failed source
must not prevent other due sources in that batch from being processed, while the job
still reports a safe failure and leaves the source eligible for the next recurrence.

Persist purge_started_at before external deletion and block further source reads. Freeze
source identity/policy/metadata once removal starts. For uploads, keep the attachment,
blob and key until storage deletion succeeds; reject a shared blob instead of deleting
another attachment's data. Perform external storage IO outside a database transaction.
Then lock again and atomically delete attachment/blob rows, clear pasted content and
record completion. If storage fails, retain the key/rows and pending state. If the final
database transaction fails after object deletion, its rollback preserves that same key
and pending state; the next attempt idempotently deletes the key and finishes. Never
mark purged_at merely because a file was detached or a failed attempt began. Do not use
Active Storage's database-first purge path, which loses the locator on storage failure.
Keep source digest, byte size, filename/kind, creator, policy, started time and true
completion provenance; preserve all official minutes graphs byte-for-byte.

Record automatic service provenance truthfully, separately from the human who chose the
policy or approved the record. Do not set the creator/Adjutant as `purged_by` and imply
they personally executed an automatic job. The current human-only purge validation will
need an explicit, narrowly scoped purged_by_service extension with a fixed known value;
human purge provenance remains supported separately. A manual early-purge UI/API is
outside this initial repair; it must not be invented as an approval shortcut.

Review cached private responses and exports for retained source copies when implementing
the promise. API transcript creation returns metadata without source text, but tests
must verify receipt bodies and log/serializer paths rather than assume they are clean.
Purging application source does not delete an external recording, provider-held data,
downloads or independently retained backups; document those boundaries without claiming
verified provider/production behavior.

## Required regression and UI evidence

Use actual pasted and uploaded synthetic sources, both policies, real attestation and
later-Meeting approval, including pending corrections and final corrected attestation.
Advance controlled time just before/at/after the chosen boundary; run the real scheduled
job/service and inspect available text, attached blob and actual storage bytes. Demonstrate
the original missing scheduling/deletion failure before implementing; a purge timestamp
alone cannot satisfy it. Exercise delayed execution, duplicate execution and an actual
storage failure followed by recovery. Check retained official graphs and non-content
provenance, controlled subsequent restricted/member reads, missing excerpts and rejection
of a new draft using an offline provider that must not be called.

Use the frontend-design skill and existing 1919 restricted-source form/status treatment
with plain finalization/30-day recovery text and 16px readable controls. Show a computed
removal date, a truthful unavailable/removal-pending state when retrying, and completion
only after storage and database removal. Retain-restricted truthfully has no automatic
schedule; no unavailable manual purge control is promised. Inspect desktop/narrow
screenshots and retain current transcript-upload and
minutes lifecycle browser coverage. Full serial ordinary/system suites, lint/security
and exact candidate/actual-main CI are required before merge. No production operations,
real data, paid AI or deletion outside synthetic test records is authorized here.

Visual direction: retain The 1919 navy source header, gold labels and paper facts panel.
Use two fact columns on desktop and one on phones, allowing the longer recovery wording
and Post-local dates to wrap. Keep status messages and fact values at 16px, labels at
13px. Keep status copy upright and padded like the source text. All HTML source dates
follow the saved Post time zone. Pending removal must visibly differ from completed removal; no new destructive
control is needed. Source HTML and explicit-content JSON responses must use no-store,
including cookie-authenticated reads and intake errors containing recoverable input.

## Initial restricted-source review (historical)

Local source and existing assertion review at `0a5686a`; no new execution or production
claim. The transcript/drafting files below remain unchanged on `b852211`:

- `Api::BaseController#transcript_summary_payload` returns source metadata, availability
  and creator, not content. Transcript creation uses this serializer. Only the explicit
  transcript GET adds text. Idempotency caches mutations only, with a SHA-256 request
  fingerprint, path and response body; it does not store the request parameters. Thus
  the normal create receipt has no full source copy in the reviewed source path.
- AI run metadata contains provider IDs, configuration, counters, source line count and
  digests. Run detail adds original suggestion payloads; source excerpts are added only
  on explicit `include_source` GET and read the current transcript dynamically. Those
  GETs do not enter mutation receipt storage. The existing evidence request test checks
  explicit normalized text, no-store, nil excerpt after a synthetic purged state, and
  content exclusion after permission loss. This does not prove actual scheduled deletion.
- Successful generation retains structured proposal narrative, missing facts and line
  ranges, without persisting its full numbered input. Failure stores a category and
  provider IDs rather than the provider exception body. The provider client has logging
  off in source; configured request filters cover nested transcript and pasted/API text.
  The filter component tests exercise actual configured filtering, not production logs.
- Reviewed proposal payloads and resulting minutes/Endeavor narrative can quote or
  summarize source. They remain restricted review or human-authored record content;
  deleting every matching phrase would invent a different record-retention policy.

Required implementation checks remain: inspect actual synthetic bearer creation and
error receipt bodies for an independent unique source sentinel; assert source-copy
absence without treating missing serializer keys alone as proof. Verify purged-state
later reads with original official graphs and real uploaded storage deletion/recovery.
External SDK/provider retention, proxy/access logging, backups, downloads and storage
configuration remain unverified and are not established by this source review.

## Independent work completed before the decision (historical)

At actual main `99371bde2c5e5963d11be0a614ff255b56a3960b`, the policy decision and
automatic removal are still outstanding. A fresh service/job/recurrence review finds
only `MeetingTranscripts::Create`, with no scheduling/purge path. No timestamp or
manual synthetic purged state is being credited as actual deletion.

PR #123 supplies the previously required source-copy evidence: real bearer creation
for both choices, actual stored receipt bodies, error/replay/current-grant denial, and
offline SDK failure followed by actual saved failed-run inspection. Four reversible
faults put a unique source sentinel into the receipt, HTML error, provider message or
saved error; each reaches the intended detector and exact source is restored. Its
actual-main CI38119436435 passed all four jobs. See
[restricted-source evidence](testing/TRANSCRIPT_SOURCE_PRIVACY_REVIEW.md).

PR #129 preserves real uploaded UTF-8 bytes, digest and metadata while fixing the
binary-encoding reader failure. Its independent five-megabyte limit fault and actual
Unicode file-control/later-reader/grant-loss browser evidence are in
[source-input evidence](testing/TRANSCRIPT_SOURCE_INPUT_REVIEW.md). Actual-main
CI38122104236 passed all four jobs. These completed checks concern source handling,
not the recovery-clock choice, actual scheduled deletion, backup erasure or provider
retention. #79 stays open. No production or paid AI was used.

## Original ordinary-approval reproduction (historical)

Ordinary approval without pending corrections has the same recorded final event under
both proposed clocks. It can be investigated now without choosing the pending-correction
boundary. Use four synthetic cases: pasted/uploaded sources and each policy, a nonempty
actual draft, Commander handoff, Adjutant attestation and real later-Meeting approval.
Capture the saved official graph and source/storage metadata. Just before thirty days,
source remains available. At thirty-one days, execute due jobs actually enqueued by
this path and inspect saved text, attachment/blob/storage presence and unchanged official
records. Expected missing-behavior detector: delete-after-acceptance source still available;
retain-restricted is the separate positive control.

This experiment checks the existing approval/queued-job path. It does not fabricate a
missing scheduler, exercise a recurrence that does not exist, prove production execution
or define the future scheduler implementation. Keep any failing reproduction on this
unmerged draft. Once policy and the real scheduling path are implemented, the final
lifecycle test must invoke that actual scheduled service/job and include pending
corrections, delayed execution, retry and storage-failure recovery. No generated minutes,
provider, external email, production or real member data is involved.

Original ordinary-approval reproduction on unchanged transcript/approval logic:
`bin/rails test test/integration/transcript_retention_reproduction_test.rb` using the
owned legion_retention_reproduction_test database passes both retain-restricted controls
and fails both delete-after-acceptance detectors:4/76,2 failures,0 errors/skips,
seed23017,1.33s. All four real final approvals, before-window source reads, retained
metadata and after-window official-graph comparisons succeed. At thirty-one days pasted
content is still present; uploaded attachment and actual Disk storage object still exist.
No deletion job is enqueued/performed. Test teardown removes only its own synthetic file
after observation; that cleanup is not application purge evidence.

At that revision, the reproduction remained deliberately failing and unmerged. It was
a diagnostic of the original approval path. The implemented regression now invokes the
actual recurring job and adds storage failure, retry, delayed execution, historical
finalization and pending-correction variants. No application fault is injected and no expected behavior is weakened. One-file
RuboCop, Ruby parsing and diff/reference checks pass. Successful older docs-only CI does
not qualify this changed draft; its expected failed regression CI is reported separately.

## Implementation evidence

See [lifecycle verification](testing/TRANSCRIPT_RETENTION_LIFECYCLE_REVIEW.md). Original
missing-path failures and the historical draft CI above remain distinct from the final
implemented candidate. The configured hourly task has been parsed and its actual job
executed with the test adapter; no production or live Solid Queue scheduler was run.
