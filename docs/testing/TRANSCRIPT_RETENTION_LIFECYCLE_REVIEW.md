# Transcript retention lifecycle verification — #79

Andre chose final corrected Adjutant attestation as the recovery-window start on
October 11, 2026 ([decision](https://github.com/AndreRobitaille/LegionPostTools/issues/79#issuecomment-6108327745)).
Ordinary approval starts at final membership approval. The original pending-correction
meeting decision remains dated when it actually occurred. See the
[approved design](../TRANSCRIPT_RETENTION_DECISION_DRAFT.md).

The recurring job selects final, due, delete-after-acceptance sources. Thirty days means
thirty full 24-hour periods; the hourly minute-37 task may complete removal after that
deadline. A later upload to old final minutes uses their original finalization time.
Retain-restricted sources have no automatic deadline. Automatic removal records its
service identity without claiming the creator or Adjutant personally removed the source.

Upload removal first commits unavailable/pending state, keeping the blob/key locator.
Actual storage deletion occurs outside a database transaction; then locked completion
removes attachment/blob rows and clears pasted content. Failed storage retains its key
for retry. A failed completion transaction after storage deletion rolls back locator
removal; an idempotent later delete reconciles it. A shared blob is refused before IO.
Normal intake creates a separate blob for each upload; the shared fixture is a malformed
synthetic guard case, not proof about arbitrary concurrent external attachment writers.

## Original failures and retained coverage

The unchanged original source at draft `cfd1f52cf389143d20038ea5edb0700c86220664`
reproduces both missing-removal cases: focused 4/76,2 failures,0 errors/skips (seed23017).
Both retain controls and official-graph comparisons pass; pasted content and actual
uploaded bytes remain at 31 days. [CI38129393451](https://github.com/AndreRobitaille/LegionPostTools/actions/runs/38129393451)
fails only those two ordinary detectors (1311/12291). That historical failing draft does
not qualify the implemented candidate.

Original normalization, bytes/digest, input refusal, manual provenance, excerpt and
unavailable-source components remain. The new regression invokes the actual job rather
than looking for a nonexistent queued task. Thirteen lifecycle cases exercise both
source kinds/policies, ordinary and pending-correction approval, just-before/exact/late
execution, duplicate execution, old final records, safe shared storage, storage failure
and completion rollback. They inspect actual stored content, attachment/blob rows and
Disk object existence, fixed metadata, revisions/attestations/approval/events and
official confirmation graphs. Test teardown is not credited as application deletion.

The model components separately enforce known automatic actor, no fake human executor,
cleared source, required times and immutable pending/completed metadata, including a
real PostgreSQL check violation. The recurrence component parses the actual YAML with
Fugit and executes the configured job through the test adapter. It does not run a live
Solid Queue scheduler.

Cookie-authenticated source HTML/JSON initially returned private/revalidate cache headers:
with assets prepared, both added no-store assertions fail (2/12,2 failures,0 errors/skips).
The scoped source controllers now prevent caching, including intake errors that return
recoverable input. The first missing-asset harness error is retained separately and is
not product evidence. Creation/error/replay receipts and configured log filtering were
already independently verified in [source privacy](TRANSCRIPT_SOURCE_PRIVACY_REVIEW.md).

A separate API case now checks actual job removal, retained proposal/official revision,
missing dynamic excerpt, fresh source metadata and refusal of locked review/new drafting.
The original manual-purge excerpt case remains unchanged. Locked final-record and
unavailable-source guards both apply to direct offline generation; the unused provider
assertion is not credited as isolating the source guard. A first expectation that final
review remained editable failed against the established lock; the independent component
was preserved and the new final lifecycle follows the governing refusal contract.

## Browser and verification scope

The source reader journey uses real magic-link sign-in, the actual Unicode upload control,
real audited attestation/approval fixture acts, pending-correction wording and final date,
actual storage failure/pending reader, actual retry/storage removal and completed reader.
It then fetches current source JSON, loses the management grant, reads unchanged final
member minutes, signs out and is refused subsequent protected access. Official actions
are fixture preparation here; their real confirmation UI remains exercised by the
separate full minutes approval journey.

The 1919 facts panel uses two desktop columns and one phone column; status and values
are 16px, labels 13px. Scheduled/pending/completed facts and source messages are captured
at 1400/390; invalid input, Unicode source and retain-restricted reader coverage remains.
Exact commands, rendered inspection, controlled faults, restored neighbors and final
candidate/actual-main results are recorded in the overnight ledger and handoff.

Application removal proves deletion from the configured synthetic database and Disk
storage object in these runs. It does not erase human-authored minutes or retained
proposals, external recordings, downloaded copies, provider-held data or independently
managed backups. Production scheduling/storage, external services and backup erasure
were not tested. No production access, deployment, real member-data copy or paid AI call
was performed.
