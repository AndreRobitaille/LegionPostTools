# Transcript retention lifecycle — decision draft

Draft for #79, October 10, 2026. This is a proposed implementation contract, not
implemented deletion or a production retention claim. Current minutes lifecycle and
approval/attestation policy govern; the existing transcript form promises deletion
after membership approval with a 30-day recovery window.

## Missing decision

Approval with pending corrections records the later Meeting's real decision before
the corrected text receives final Adjutant attestation and becomes locked. Choose
whether the recovery window begins at that recorded decision or at final corrected
attestation. Proposed choice: final approval/locking, so restricted source remains
available while the authorized officer finishes corrections. The decision is pending;
no dependent purge scheduling, data deletion or altered UI promise has been implemented.
Ordinary approval without pending corrections would start at its recorded final approval.

## Current evidence

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

## Proposed implementation after the decision

Persist the computed due time from the exact final/pending approval event chosen above.
Use one bounded recurring job to find due delete-after-acceptance transcripts and a
single idempotent service for actual removal. Recheck the selected policy, source state
and governing approval under locks when performing work, rather than trusting an old
queue argument. Delayed execution must remove a still-due source on the next run; repeat
execution must leave records/audit intact. Retain-restricted never enters automatic purge.

Clear pasted text. For uploads, delete both attachment/blob records and the private
storage object, with retry-safe failure handling: do not announce successful purge
while a retained file is merely detached or a storage deletion failed. Define the
failure/reconciliation state explicitly before coding. Keep source digest, byte size,
kind, creator, policy, schedule and true completion metadata; preserve every minutes
row, revision, attestation, recorded approval and lifecycle event byte-for-byte.

Record automatic service provenance truthfully, separately from the human who chose the
policy or approved the record. Do not set the creator/Adjutant as `purged_by` and imply
they personally executed an automatic job. The current human-only purge validation will
need an explicit, narrowly scoped provenance extension. A manual early-purge UI/API is
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

When policy is resolved, use the existing 1919 restricted-source form/status treatment
with plain schedule/removal text and 16px readable controls. Invoke the frontend design
skill, inspect desktop/narrow screenshots, and retain current transcript-upload and
minutes lifecycle browser coverage. Full serial ordinary/system suites, lint/security
and exact candidate/actual-main CI are required before merge. No production operations,
real data, paid AI or deletion outside synthetic test records is authorized here.

## Restricted source-copy review while the decision is pending

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
