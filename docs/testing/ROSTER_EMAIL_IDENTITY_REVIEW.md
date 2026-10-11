# Self-service roster email decisions preserve actual identity

Design for #108 under #84, source `f5fc283`, October 11, 2026. Current governing
user-management workflow keeps National roster email separate from login email. A signed-in
member may choose to use the roster email, retain their own login email or defer review.
The current controller's invalid branch redirects with the existing alert and does not
write identity. This is missing saved-state evidence, not a reproduced runtime defect.

Retain all five existing request cases and all thirty User component cases. Strengthen
valid decisions with independent stored reviewed address, decision and timestamp, actual
login address, unchanged National person data, account access/permissions/session identity
and later protected Profile reading. The request helper remains setup, not real sign-in
proof. Keep User mismatch/keep/remind predicate assertions beside explicit saved metadata.
No new rule about email verification or ending sessions is invented.

Strengthen invalid and unauthenticated requests with full saved person/User/grant/session
graph equality before redirect/alert assertions. An unauthenticated request should preserve
an actual existing member record, then later authenticated Profile reading should still
work. Include another identity so current-user scoping cannot be assumed from a single
record. Use the test environment and synthetic addresses/records only.

A narrow offline fault makes only the invalid-decision branch update login/review fields
while retaining its original alert/redirect. New saved-state assertions must fail even
though old response checks could pass. Restore exact controller bytes in finally and prove
clean focused behavior. No application policy/code change is proposed for this coverage.

Add one actual browser journey for the existing Dashboard email card. Preserve the 1919
navy/paper system, visible fixed addresses and plain action/refusal text. Submit a tampered
invalid decision through the real existing form, prove identity remains unchanged and
inspect desktop/390px refusal renders without overflow. Exercise ordinary update/keep
choices and later protected reading; exercise remind-later suppression in the current
session, actual sign-out/protected denial and a fresh real sign-in that prompts again.
Record actual stored outcomes; neither a predicate nor a status alone establishes them.
No new UI template/style or fake auth endpoint.

Combine the two related coverage-only roster boundaries (#108 and offline source/call
continuation #109) in one scoped review candidate, keeping separate designs and faults.
Before commit: restored clean focused/browser checks, lint and whole intended diff review.
Before merge: final committed full ordinary/system serially, security, exact-SHA and
actual-main CI. No prior assertions removed/consolidated, production operations, member-data
copy, external mail/provider calls, paid AI or deployment. #93 date and #79 retention
choices remain separate unresolved decisions.


## Focused fault and browser evidence

Integrated877c18e combined roster/User focus54 /260 /0 (seed9071,1.81s). Invalid choice
fault keeps the old alert/redirect but writes login/review fields; the strengthened request
fails1 /1 /1 (seed60486,.95s) on saved full identity before response checks. Exact controller
SHA256 `a8ecdba6c284ecd35eb59f2adbd650211c107dfad2b36ce9ee424c34a5781b74` restored in finally.
No application policy or fault remains.

First browser setup failed on nested Rails time blocks (1 /1 /1error,seed31066); removed
nested blocks while retaining five-minute authentication/review distinction. Next new
browser expectation wrongly assumed Profile displayed the login address (1 /17 /1,
seed17349). Actual template displays own name; corrected only that new assertion to
check own Profile identity and exclude a real foreign member. Stored actual login address
assertion remains. Corrected browser1 /62 /0 (seed35891,6.85s), combined pair2 /98 /0
(seed32111,9.63s) pass. Desktop/390px refusal screenshots inspected with readable wrapped
addresses/action text and no overflow. All three ordinary choices, current-session remind
suppression, real sign-out/protected denial and fresh sign-in re-prompt execute.

All five original controller cases and thirty original User cases/assertions remain.
Valid account graph comparison excludes only the independently checked login/review fields
and updated_at for the actual target; foreign User/access/grants/sessions and National
person data stay exact. Negative paths compare every stored field. User keep/remind
component metadata assertions complement the original predicates; its unique person,
sole-admin/manual/roster-status/role/grant/full-membership/private-notes cases remain
unchanged and separately reviewed under #107/#112/#78. No safe redundancy is demonstrated.
Full committed serial suites/security/exact candidate/main CI remain pending.


A fresh review made saved grant preservation non-vacuous: both the actual reviewed
member and a distinct foreign account now have existing literal grants, compared
unchanged on invalid/valid actions. Refined focus54 /260 /0, seed7997,1.71s passes.
The browser records those existing grant attributes beside identity/session metadata;
new focused browser execution is required after this refinement.


Fresh main55e091f integration: complete focus54 /260 /0 (seed55531,1.81s), then
real browser pair2 /105 /0 (seed15602,9.63s), all restored. Final narrow partial-failure
detail and remind-refusal captures inspected; clear wrapping/source identity and usable
follow-up controls without overflow. Focused Ruby lint5 files and diff checks pass.
All final committed full suites/security/exact candidate/main CI remain subsequent gates.
