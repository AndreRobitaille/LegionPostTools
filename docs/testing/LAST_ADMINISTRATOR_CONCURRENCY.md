# Preserve an enabled technical administrator during overlapping changes

Design for #112 under #84/#78, initial source `a88f11e`, October 11, 2026.
`docs/USER_MANAGEMENT_GUIDE.md` requires at least one enabled person with Manage settings
and promises to refuse both disabling and removing that final account's grant. Technical
administration is distinct from Commander/Adjutant official authority; no office, implicit
approval privilege or new administrator policy is proposed.

The five existing permission replacement tests retain valid capability filtering,
automatic-role deduplication, sole-admin refusal and permitted removal with another admin.
Current replacement checks the other admin before its transaction. User manual disable
and roster control already lock relevant admin rows inside a transaction. An overlapping
removal could therefore invalidate another request's earlier observation. This is a source
candidate, not an established runtime/production lockout.

## Reproduction and required outcome

Use two enabled synthetic technical administrators and independent actual authenticated
HTML request sessions/database connections. Hold the first target's actual settings grant
row in a separate PostgreSQL transaction. Start its real removal request and observe its
blocked SQL through `pg_blocking_pids`. Start the second operation while the first is
blocked. Wait until the second either finishes or actually blocks behind the first, then
release the external row lock. This schedules the actual read/write window; it does not
replace an authority predicate or inject an invented guard result. Bounded polling/joins
must fail clearly and release locks/threads in ensure; no indefinite waits.

First exercise two self grant-removals. Inspect stored enabled settings-admin identities
before response assertions: exactly one must remain. One actual request must report the
permitted operation, the other the existing last-admin refusal. Original people/account
identity and unrelated manage-people grants must remain. A later actual administrative
read must succeed for the survivor and be denied for the removed account. Also exercise
manual disable and roster-controlled disable against the overlapping grant removal;
both existing routes must share the same preservation boundary. Separate serial component
and request cases stay useful and must not be removed.

If reproduced, place actual manual permission replacement and last-admin check in the
same User transaction/locking boundary as disable/roster changes. Keep submitted capability
validation and automatic-role filtering; keep existing refusal text/redirect and all
ordinary permitted changes. Acquire relevant User locks in consistent primary-key order,
with PostgreSQL locks explicitly on User rows, then check current persisted authority.
Avoid unrelated permission/office policy, blanket rescue, external locks or infrastructure.
Do not implement this conditional repair before reproducing the original failure.

## Visible behavior, verification and limits

The intended visual direction preserves the 1919 person permissions panel and its existing
plain success/refusal alerts. No template or style change is proposed. Actual browser
serial refusal and later permitted controls/read complement the routed concurrency checks;
inspect desktop/390px renders with readable actions and no overflow. Browser setup sign-in
alone is not proof of permission replacement.

Before commit: original saved-state failure or explicit disproof, clean focused grant/User/
account/roster checks, no experimental faults, lint and complete intended diff review.
Before merge: final committed ordinary then full system suites serially, security, actual
browser refusal/recovery, exact-SHA CI and actual-main CI. Every prior assertion remains.
Only disposable test databases/synthetic records; no production operation, member-data
copy, paid AI call or deployment. PostgreSQL connection/locking evidence is local/CI,
not production evidence. #93's date policy remains unresolved and independent.


Initial harness attempt timed out (1 / 4 / one error, seed2003, 11.02s): SQL logs show
the actual DELETE blocked, but repeated observer queries reused a cached empty
`pg_blocking_pids` result. Make only these observer queries uncached so each reads real
PostgreSQL wait state. Exact requests and authority logic remain untouched; this setup
error is not an application reproduction. Locks were released and requests joined before
synthetic cleanup. Rerun is required before a defect or repair is established.


Uncached original reproduction on `283911d`: 1 run / 7 assertions / one failure,
zero errors/skips (seed27822, 0.92s). Two actual requests complete and stored enabled
settings-admin count is zero; the test fails before response assertions. This establishes
the local synthetic defect. No application fault was injected.

Refined locking design: select enabled manual settings-admin User IDs plus the current
target ID in a subquery/OR relation, lock the outer User rows in primary-key order, then
retain the existing `lock!` reload/dirty-record safeguard on the already locked target.
The outer relation has no grant join, so FOR UPDATE locks User rows without incidentally
locking grant rows in a different order. Including the target even when disabled avoids
an out-of-order extra target lock and permits fresh-state checks during simultaneous
re-enabling. This same helper remains shared by existing disable/roster methods.
Manual permission replacement validates capabilities and removes current office-derived
duplicates within its transaction, then uses existing sole-enabled-admin logic before
writing. Controller only translates the existing skipped result into its existing alert.


## Corrected focused and browser evidence

All three actual overlap scenarios pass 3 / 63 / 0 (seed63849, 2.02s): one saved
eligible administrator survives, identity/unrelated grants/session authority remain,
one refusal and one actual accepted message render, and later administrative reads match
current authority. Neighboring real grant/User/HTML+API account/roster/officer checks pass
92 / 728 / 0 (seed503, 8.47s). Original five serial grant tests and every old assertion
remain; no consolidation/deletion. Actual SQL logs show the outer User-row FOR UPDATE
relation ordered by User primary key; no grant join is locked by that outer query.

New real browser sole-admin refusal at1400/390 plus later permitted successor handoff
passes 1 / 22 / 0 (seed64819, 4.70s). The original grant and person/account graph stay
unchanged after refusal; real form removal when a successor exists drops only settings,
removes old management controls and denies later administrative navigation, while actual
successor sign-in permits the roster upload screen. Both refusal captures inspected:
plain readable alert and no horizontal overflow. No browser concurrency claim is made.
A pre-existing local account panel incorrectly advertises National roster provenance;
that observed display discrepancy is linked separately in #115 before any presentation
change, and is not silently repaired or asserted as correct in this locking slice.

Focused three Ruby files lint clean; browser file lint/final complete diff and integrated
candidate checks remain required. No injected application fault remains: the original
unmodified implementation supplied meaningful failure detection. Sources/runner setup
are synthetic and local; no production lockout or paid/provider operation is claimed.


Fresh source review refines the shared boundary: every manual permission replacement
and every manual disable acquires relevant administrator/target User locks, rather than
first testing the target's present manage-settings grant. Authority can change between
that initial read and mutation; a present non-admin target may receive a grant while
another administrator is removed. Serialize the mutation before testing current saved
state, including additions, and preserve current permission results. This is a locking
scope correction, not a reproduced separate three-request defect or permission change.
The recorded 92 / 728 and browser results precede this two-line refinement; new focused
and final committed suites are required for the refined candidate. Existing roster and
roster-control disabling already enter the same helper without a pre-lock can? check.


Final integrated pre-commit focus onf5fc283 passes123 / 971 / 0 (seed4316,10.45s),
including the explicit distinct observer/request PostgreSQL IDs and complete new roster
upload controller. Refined browser1 / 22 / 0 (seed34244,4.68s) after both lock-scope
changes. All four changed Ruby files lint clean; intended diff reviewed. No application
experimental fault remains. Commit this candidate before final qualifying serial suites;
those/security/exact-SHA/actual-main CI remain pending.
