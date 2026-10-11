# Final Meeting occurrence context

Design for #80, October 10, 2026. The governing
[minutes lifecycle](MINUTES_LIFECYCLE.md) makes a Meeting's historically significant
heading, time, body and venue immutable when its minutes become membership-approved.
This protects the occurrence as well as the immutable minutes revision. Later corrections
belong in a later record; amendments remain planned.

## Protected contract

Protect `organization_id`, `meeting_body_id`, `meeting_type_id`, `starts_at`, `title`,
`location_name` and `location_address`. Changing even one after final approval is refused
with plain feedback, without changing the persisted Meeting, saved document/revision,
source links or recorded approval. Protection is independent of the presence/status of
an agenda: absent, draft, or reopened agendas cannot unlock the final Meeting.

Before final approval, retain existing draft editing and agenda synchronization/locks.
An approval decision with corrections pending does not become final until the Adjutant
attests corrected text; this design does not impose the final lock early. Existing
independent minutes heading snapshots do not automatically follow Meeting edits.

Dedicated website notice fields and ordinary calendar metadata remain editable under
existing authority; they do not rewrite occurrence/document identity. No publication
eligibility or permission expansion is part of this work. Do not treat a website notice
edit as a means to replace historical title/time/place.

## Implementation and verification approach

Add a model guard checking current persisted final-minutes state before the existing
agenda-based conditions; avoid an early return on absent agendas and stale cached
association authority. Define the historical field set explicitly. Request/API paths
retain their existing validation handling; no new screen or control is required.

The 1919 visual direction remains the existing bounded form/error summary, system sans,
red attention text, readable sizes and ordinary navigation. Inspect final-update refusal
at desktop and 390px, then read the surviving member record/document.

Exercise the actual attestation and later same-body approval lifecycle with synthetic
records for no agenda, draft agenda and reopened agenda. Assert individual field refusal,
persisted context, immutable revision/digest/approval identity and member HTML/PDF selection.
Keep draft/pending-corrections and dedicated website edit success coverage.

Database immutability must also survive fresh schema preparation. #86 investigates the
current Ruby-schema omission of existing PostgreSQL guards; coordinate a database-level
occurrence guard with that verified schema path. Do not claim direct-SQL protection from
model/request tests alone.

The database guard compares the seven historical fields with null-safe comparisons.
Finalization also locks the parent Meeting row before committing the final state, so
an overlapping occurrence update and finalization serialize on that row. An update that
loses that race returns the same specific validation refusal; unrelated SQL failures
remain errors. Test direct writes and a controlled two-connection race as well as normal
form/API refusal. Preserve existing append-only triggers and normal pre-final writes.

Separate neighboring question: a Meeting used as the approving occurrence of another
final record may have no finalized minutes of its own. Whether its editable occurrence
fields need the same lock is not resolved by the literal own-minutes rule above. Record
that variant for explicit review rather than silently inventing or overlooking policy.

## Original-code evidence

Unchanged original code `b092bf6789d7611d55747ebc1acdc5bf85b6b369` in a separate
synthetic checkout/database: `bin/rails test test/integration/final_meeting_context_test.rb
--name '/refuses final historical changes/'` produced 6 runs / 6 assertions /
6 failures / 0 errors/skips (3.02s). Each no-agenda/draft/reopened HTML/API variant
accepted the attempted title rewrite after actual attestation/later-meeting approval.
The original regression stops at that first refusal assertion; this does not prove
all remaining field variants were independently exercised on the original code.

The proposed fixed integration assertions now compare reloaded occurrence and official
graph before response/feedback assertions. Model tests include stale loaded pre-final
minutes, each of the seven explicit fields, direct SQL exceptions and unchanged records.
Pending corrections remain editable before final attestation; subsequent dedicated
website edits preserve the historical field set and signed record.

The existing approval browser scenario is retained and strengthened with real final
Meeting edit refusal at 1400/390px, ordinary member archive navigation and actual final
PDF bytes/text. Its current record authority label is “Approved as corrected”; the
officer status label is “Approved and locked”. These are distinct intended surfaces.
The strengthened original-code graph assertion independently reproduced persisted title
mutation: one run / one assertion / one failure, before any response assertion. The signed
minutes remained unchanged, demonstrating why that alone is insufficient protection.

Focused final-context/model/controller checks: 46 runs / 560 assertions / no failures,
errors or skips (seed 41535). The initial new-worktree run had thirteen missing
`tailwind.css` errors; building the locked Tailwind assets resolved that preparation
problem without changing expectations. Focused browser verification passed at desktop and
390px, including original occurrence identity, actual member navigation and real PDF
contents. Inspected refusal screenshots are readable and have no horizontal overflow.
Final committed-candidate verification is still required.

`test/manual/final_meeting_context_race.rb` is an explicit test-environment runner, not
an automatically discovered test. It refuses every database name except the owned
synthetic `legion_context_race_test`. Run with `bin/rails runner` against an empty,
migration-prepared copy of that database, with `ENDEAVOR_HISTORY_ENABLED=0`. On local
PostgreSQL 18.6 it proved actual finalization held the parent-row lock, a second connection
waited on that lock, and the subsequent historical update returned the specific refusal.
The occurrence, signed revision and later-Meeting approval survived unchanged. The first
probe cached its observer query and incorrectly reported no wait; using an uncached
`pg_stat_activity` read corrected the observer. No trigger or model fault was left installed.
