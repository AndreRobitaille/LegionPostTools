# Endeavor history database contracts

Design for #88/#95, a bounded #84 follow-up, October 10, 2026. SQL schema fidelity was
repaired under #86; this slice proves the six Endeavor triggers' actual behavior in
fresh synthetic test databases. Inventory alone does not prove protection. No production
guard claim or paid provider call is made. A reproduced input-provenance gap requires
one narrow database-function repair.

## Boundaries

Existing offline EndeavorHistoryTest covers source discovery/citations/coverage,
publication/withdrawal, authority, input/budget limits, immutable edition/result model
callbacks, pending/recovery/reuse and preserved historical accounts. Retain every test
and assertion: model callbacks and full offline pipeline outcomes have distinct value.
Direct SQL guard coverage bypasses those callbacks and requires the actual trigger
message plus unchanged persisted records, so unrelated FK failures cannot pass.

Append-only guidance, events, editions, source links and verified result records must
reject SQL update/delete. A run's manifest, fingerprint, Endeavor and requesting person
and recorded agent token are immutable even while pending/running. Pending/running progress, steps, intermediate
artifacts and heartbeat/recovery timestamps may change; normal completion may persist
its final status and result metadata. Once succeeded, failed or superseded, the whole
run must reject update/delete. Active runs also cannot be deleted. These rules come
from current immutable-history design. The current PostgreSQL function protects the
first four input fields but omits the recorded agent token.

## Reproduced gap and repair

On candidate `31231f6`, fresh-schema tests run 19 cases with 143 assertions and two
failures: changing `agent_access_token_id` on pending and running jobs succeeds and
changes the persisted row. The other immutable-table and terminal-state cases pass.
`Processing.request` records the token when creating the run and its requested event;
recovery creates a new run with the original token. `ensure_current!` checks the run's
recorded token for revocation before continuing work. Replacing it therefore changes
the delegated provenance and the credential checked by the worker. This is direct SQL
evidence; it does not establish an ordinary API route that permits this alteration.

Replace the existing function through a reversible migration, adding only
`NEW.agent_access_token_id IS DISTINCT FROM OLD.agent_access_token_id` to its existing
refusal condition. Preserve all other guards and legitimate progress updates. Existing
nil tokens remain nil; this does not add a token requirement to background work.

Use minimal valid synthetic relational fixtures with actual minutes attestation and a
resolving source-link key/unit; they prove guard behavior, not AI output validation.
Retain the existing full FakeProvider pipeline tests to prove real publication/recovery.
No source links may be detached or cascaded to make a delete pass.

## Verification and detection

Exercise each immutable table for update/delete, all terminal run states, active input
fields/delete, and positive pending-to-running/progress/completion with exact preserved
inputs. Check the original saved attributes before inspecting the specific SQL refusal.
Keep SQL savepoint failures contained so subsequent reads prove persisted preservation.

A controlled test-only fault disables only the edition trigger inside that test's
transaction after fixture creation. The SQL update must change the persisted payload
and fail preservation despite bypassing all model callbacks. Test rollback restores
the DDL; Python finally restores the exact test bytes. Recheck enabled trigger inventory
and clean behavior; no test-only trigger installation or disabled guard remains.

Use a fresh owned test database loaded through the normal SQL schema path. Focused
existing/new component tests, full serial ordinary/system suites on the final committed
candidate, lint/security and exact candidate/actual-main CI qualify the merge. Broader
suite slices remain open under #84. No tests are removed, consolidated or weakened.

## Focused evidence

After the repair, initial guards plus retained offline pipeline and official guards pass
74 / 416 / 0. Add active token-to-nil and nil-to-token variants, plus actual revoked-token
worker refusal before any offline provider call. Strengthen the existing recovery test
with original token/run/requested-event identity; retain every earlier assertion.
Final restored focused set: 76 / 436 / 0 (seed 4609, 11.24s).

The controlled edition-trigger fault changes a saved payload and fails its preservation
assertion before checking an SQL error: 1 / 1 / one failure (2.76s). Python finally
restores exact test bytes; transactional rollback restores the guard. All 13 real triggers
are enabled afterward. The fault restoration SHA-256 was
`86dbe5d27cf900bac921392b45ec1bbbc34b69d7ebfa538d60bbb7a9582f383d`;
later fixture refinement splits nil-token active states into separate tests because the
real unique index correctly rejects two active runs for one Endeavor, and explicitly
uses a nil requester for system-run fixtures. That initial
fixture error is excluded from regression evidence; no index or expectation was weakened.
No temporary trigger installer or disabled guard remains.

Logs: `/tmp/legion-endeavor-original-guards.log`,
`/tmp/legion-endeavor-edition-fault.log`, and
`/tmp/legion-endeavor-restored-final-guards.log`. These establish synthetic local behavior,
not production or paid-provider verification. Migration round-trip/fresh-schema and final
committed suites/CI remain required and will be recorded in the overnight ledger.
