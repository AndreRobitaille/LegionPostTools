# Shared discovery for newly attested minutes

November 5, 2026. Implementation scope: share complete-source extraction and its
independent verification; retain separate history composition and verification.
The model profile, official-record authority, and member presentation stay the same.

## Expected officer and member outcome

Attesting a meeting should not pay to read the same source separately for every
Endeavor. One extraction/check pair examines all eligible human-defined Endeavors,
including completed ones and untagged mentions. Only histories with changed facts
need new prose. The frozen minutes, primary links, and officer actions are never
rewritten. Members keep the existing source-backed history and source reader.

For one small source batch, ordinary discovery is two calls for the meeting, rather
than two per Endeavor. Larger sources retain whole-item batching and explicit input
limits. This is a call-count contract, not a measured dollar or accuracy claim.

## Scope and durable authority

When the shared-discovery switch is enabled, attestation records the same durable
per-Endeavor requests as before, adding a common group ID and frozen target identities,
guidance, and generations. Withdrawn histories are excluded; completed identities
remain eligible. The full catalog remains available to distinguish annual events.
No paid work occurs inside the attestation transaction.

The shared path applies to the triggering attestation's revision. Older pending
revisions, existing queued requests, manual searches, and explicit refreshes retain
their established target-specific processing and authority. This bounds the initial
change and does not expand a newly created Endeavor's historical search scope.

Each source batch returns exactly one complete item/outcome coverage record for every
target. A separate shared verifier checks every target against the complete supplied
source, including negative matches. Structural checks reject missing/duplicate targets,
invalid citations, ambiguity, lost outcomes, or missing primary links. A failed batch
gets at most one repair pair; unresolved failure publishes none of that batch.
There is no cheaper preliminary filter or silent target-specific paid fallback.

## Sharing, interruption, and recovery

A database-unique discovery record identifies organization, group, exact source batch,
target context, and stage configuration. A PostgreSQL session advisory lock serializes
its producer without holding row locks during provider calls. Other Endeavor runs
wait and requeue without making paid calls. The producing run records usage once in
the existing stage ledger and saves the accepting shared result append-only.
Consumers record provenance pointing to that result, then use the existing per-Endeavor
fact IDs, composition, publication, and source readers.

The producer's existing bounded retry authority owns recovery. Followers cannot turn
a failed shared call into one retry per Endeavor. Completed producer stages are reused
on an authorized retry; unknown timeout costs retain reservations. Permanent failures,
daily-budget failures, or exhausted retries stop followers. Disabling history, withdrawal,
changed source/catalog/guidance, and revoked manual authority are checked before paid
calls and publication. A changed shared target context invalidates the shared batch.

Shared operational state can progress, but its input identity cannot change. Accepted
results retain database append-only protection. Every consumer still checks its own
current source snapshot and authority; a reusable result never grants spending authority.

## Qualification and rollout

`ENDEAVOR_HISTORY_SHARED_DISCOVERY_ENABLED=1` opts new attestations into this path;
the default remains off until a separately authorized, bounded model-quality evaluation.
Turning it off stops queued shared work rather than silently multiplying calls through
the old path. The current model/effort settings apply to the corresponding shared stages.

Offline fixtures must prove one shared pair across multiple histories, completed and
untagged matches, no-match verification, source-reader provenance, unchanged official
records, correction replacement, stale authority, concurrent producers, recovery after
extraction, permanent failure fan-out, and no next-day budget replay. Existing tests
remain useful for manual searches and publication. Synthetic provider fixtures establish
mechanics, not actual model recall. Paid qualification must independently inspect source
facts, annual-identity ambiguity, mixed reports, corrections, negative coverage, and
repair cost before enabling the switch in production.
