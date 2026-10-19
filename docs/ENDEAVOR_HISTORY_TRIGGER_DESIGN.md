# Attestation-triggered Endeavor History

October 19, 2026. Implements issue #157; replaces the incomplete enqueue-only design in PR #158.

## Spending authority and durable work

Each successful attestation records an `attestation_requested` event for each currently
eligible, non-withdrawn Endeavor, inside the same database transaction as the immutable
revision and attestation. Existing append-only history events provide the journal;
no new queue subsystem or historical backfill is needed. Each event records its exact
revision and source/catalog/guidance inputs independently of provider configuration;
invalid AI settings must not block an official attestation. A rolled-back attestation records no request.
Disabled processing records no request. Later-created Endeavors cannot inherit old requests.

After commit, refresh jobs carry both Endeavor and request-event IDs. Queue refusal or
exceptions leave the journal intact. Reconciliation recovers outstanding recorded work;
it never treats a missing edition or changed fingerprint as spending authority. Legacy
refresh jobs with only an Endeavor ID are harmless no-ops.

Dispatch the newest outstanding request with valid context; its run reads all current
member-visible revisions. Older outstanding requests resolve against matching terminal
work, rather than being discarded based on event ID or commit order. A request is resolved only by its linked run or an
explicit resolution event naming an already terminal matching run. Returning an unrelated
active run never resolves a newer request. After that old run finishes or is superseded,
reconciliation dispatches the outstanding request. Concurrent dispatch uses the existing
Endeavor lock, unique active-run index, and worker claim.

Catalog, target identity, guidance, generation, and quality-policy context must still
match the request. Context drift defers it until a new attestation or explicit refresh;
it does not grant new spending authority. Source revisions can advance while attestation
transactions overlap: outstanding requests may cover the current attested corpus, while
strict run fingerprints still prevent stale stages or publication. Completed requests
never restart because sources or configuration subsequently changed.

## Retry and authority

Recovery names the failed run directly, independently of the current fingerprint lookup.
It copies the original requester, delegated token, meeting scope, refresh identity, and
retry-root ID. Legacy manual `refresh_id` chains count toward the same retry cap;
rollout does not reset their existing attempts. Source/catalog/guidance drift defers recovery instead of converting it
into system work. Revoked authority prevents provider calls and publication. Transient
retries remain delayed and bounded; daily-budget recovery remains next-day. Completed
stages and timeout reservations retain existing reuse and accounting semantics.

Only runs with established journal provenance, a recorded manual request, or an explicitly
recorded operator backfill may execute/recover through production job entry points. Old
unproven system work is retained as failed audit history and cannot block a new authorized
request. No migration manufactures requests for old attestations or missing histories.
Existing manual requests with intact immutable request metadata remain recoverable.

Publication locks minutes before the Endeavor, matching attestation's lock order when it
inserts history events. This avoids introducing an inverse lock order at the new journal
write. Official records remain immutable; only derived requests/results are affected.

## Verification

Use synthetic sources and an injected offline provider. Demonstrate failure on the old
PR for active-run overlap, lost enqueue, and manual recovery drift. Verify later member
reads, rollback, duplicate/concurrent dispatch, multiple overlapping attestations,
transient/daily-budget/semantic failures, revoked authority, disabled/withdrawn/foreign
boundaries, explicit web/API operations, legacy rollout, and evidence reuse. No paid
provider call or production operation is needed.

## Recorded verification

Three workflow regression checks against the original PR head `10d4d99` failed as
expected (3 tests, 16 assertions): active-run overlap lost the newer attestation, queue
refusal left no recoverable work, and catalog drift created an unscoped system retry.
The same workflow assertions pass with the corrected journal and retry paths. The final
focused service/controller/database-guard run passed 111 tests and 887 assertions, with
no failures, errors, or skips.

`test/services/endeavor_history/triggers_test.rb` exercises the actual refresh/worker
jobs with an injected offline provider. Controller tests cover web guidance followed by
explicit Refresh and later member HTML/JSON reads, plus idempotent bearer scoped Refresh,
withdrawal, and explicit Resume with retained token provenance. Database guards continue
to protect immutable evidence and original run inputs.

The isolated PostgreSQL script `test/manual/endeavor_history_request_race.rb` refuses
any database except an empty `legion_history_request_race_test`. Concurrent dispatch
waited on the real Endeavor row lock and created one run. Two workers made four offline
provider calls and published one edition. Two overlapping attestation transactions, each
capturing a partial source snapshot, produced one current replacement, retained old
verified evidence, made six new offline calls, and resolved both requests. No production
data or paid provider was used. To repeat, create the named empty test database, load
`db/structure.sql` using `RAILS_ENV=test` and its explicit `DATABASE_URL`, then run the
script with `bin/rails runner` under those same settings.
