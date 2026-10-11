# Database schema guard fidelity

Design for #84/#86, October 10, 2026. Existing governing minutes policy requires
append-only official revisions, attestations, lifecycle events and membership approvals,
and prevents any update/delete of membership-approved working minutes. Existing
Endeavor history migrations also define immutable verified evidence and completed-run
protection. This work preserves those existing contracts in fresh preparation.

## Reproduced preparation discrepancy

Source/candidate: `9d971a32d904f42d57a47257870cd194ce23469b`.
A fresh database prepared with the Ruby schema contains zero non-internal triggers.
Directly running all migrations into a separate blank synthetic database creates eleven.
Even `db:create db:migrate` uses schema initialization before migration in this Rails
version, so the migration-only comparison explicitly calls the connection pool's
migration context on a fresh blank database. No development or production data is used.

## Intended schema path

Use Rails' PostgreSQL SQL schema representation so custom functions/triggers survive
schema load, fresh test preparation and parallel worker preparation. Generate schema-only
output from the migration-built synthetic database, never from a member database.
Keep one authoritative schema and update current references to it. Preserve versioned
migrations and their existing rule definitions rather than a hidden test-only installer.
CI must provide compatible PostgreSQL dump/load clients and exercise the same path.
No production operation or dependency upgrade is authorized by this design.

## Evidence and limits

Focused component tests must distinguish actual guard exceptions from unrelated foreign
key failures. Test direct update/delete attempts inside savepoints, assert the guard's
specific refusal and unchanged records, and retain valid draft-write behavior. Inspect
the expected custom triggers as a preparation inventory, separately from tests
proving their behavioral rules. Existing model, request and real browser tests remain.

Prove tests fail on the original schema-loaded database, then pass with the faithful
schema. Compare function/trigger definitions between migration-built and reloaded
schemas. Full ordinary/system suites run serially on the final revision and exact-SHA
CI is required before merge. If preserving previously omitted guards exposes a real
workflow failure, reproduce and repair it separately; do not disable guards or relax
assertions to restore a passing suite.

This establishes local/CI schema fidelity. It does not inspect, alter or prove the
currently deployed database's state. #80's new occurrence-context safeguard must use
this faithful schema path before claiming database protection.

The #86 baseline inventory contains eleven triggers. #80 adds the occurrence-mutation
guard and finalization parent-row lock, raising the current expected inventory to thirteen.
Their behavioral proof is documented in [Final Meeting context](FINAL_MEETING_CONTEXT.md).

The initial CI baseline ran PostgreSQL 18.6 and already used libpq 18.6; local checks
also run on 18.6. Repository deployment and Cloud development configuration use 17,
and the Dockerfile already installs PostgreSQL client tools. Pin CI's service/client
to the repository's configured major 17 to prove this standard dump loads there as
well. This changes CI only, without inspecting or altering production configuration.
Standard Rails PostgreSQL dump output is retained; Rails 8.1 strips dump header/restriction
meta commands. No custom dump flags or guard installers are added.

The first candidate CI failed during package setup: libpq 18 was preinstalled, but
the runner's enabled apt sources could not locate client 18. Configure PostgreSQL's
[official signed Ubuntu repository](https://www.postgresql.org/download/linux/ubuntu/)
for the runner's actual distribution before installing the selected client. This affects CI
only and requires a successful new candidate run; no production package operation.

The first migration-built test comparison also failed because Rails test schema maintenance reloaded the Ruby schema (schema SHA metadata was absent), dropping its eleven triggers before tests ran. This reinforces the need to repair the real preparation path rather than inject guards only in test setup.
