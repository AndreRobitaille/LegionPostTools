# Official confirmation lifetime and atomic consumption

Bounded #131/#84 verification design, source b965cf76, October 11, 2026.
The governing minutes lifecycle requires ten-minute, one-use confirmations consumed
in the same transaction as the official mutation. Current approval documentation
retains user/session/action/text binding and separate human versus delegated provenance.
The existing Session tests, minutes model/request components and real approval browser
journeys already establish useful successful and detached-session behavior. Keep every
assertion. No application defect is established by the missing direct expiry detector.

Add the lowest sufficient direct model cases: independent fixed ten-minute factory
lifetime for all three provenance methods; actual attestation before expiry; expired
confirmation and expired consumption refusal; wrong live user/session refusal; consumed
reuse; and rollback after a narrowly injected persistence-phase failure. Save and compare
confirmation, structured minutes, revisions, attestations, events and source rows. Use
nonempty minutes wording. Later fresh confirmation or restored persistence must complete
the same real attestation with the correct saved human identity, revision and provenance.
Do not assert a newly invented exact-boundary policy: use nine minutes and ten minutes
plus one second. No fake usable predicate or provider is needed.

For atomicity, let the real revision, attestation, minutes transition and lifecycle event
be written inside their transaction, then raise an explicit persistence-phase exception
in the narrowly replaced event method. Its ensure-backed replacement restores automatically.
Check that all stored writes and consumption roll back, then reuse that same confirmation
successfully. This injected failure is separate from a reproduced production incident.

Demonstrate a narrowly removed expiry guard reaches the stored-state/refusal detector,
restore exact source, then run relevant existing model/request/browser neighbors.
No broad rescue, skip, deleted test, authority change, official-record rewrite, new UI,
paid provider call or production operation. Final committed ordinary and system suites
run serially, with lint/security and exact-candidate/actual-main CI before normal merge.

Initial seven-case run:7/138, zero failures, one setup error, seed1814. This environment
does not expose Object#stub; replace only the synthetic instance's event method using
the project's ordinary singleton-method pattern and remove it in ensure. No application
defect or rollback result is credited to that failed invocation.
The next7/139 run fails one assertion, seed16676: the replacement method executes
with the minutes receiver, so the test's instance variables are unavailable there.
Capture the test and minutes explicitly; keep the same persisted-phase preconditions
and ensure restoration. This fixture failure does not establish an application defect.

Corrected seven-case component run passes7/163, seed12825, 1.28s. Removing only
the expires_at.past? guard makes both expired-unconfirmed and expired-confirmed
refusal tests fail because no exception is raised:2/2/2 failures, seed12134, 0.90s.
Exact model restoration SHA256ba6efaa8472c1c6fbef156b62be56319be4ff5ffb08da5f204bf308165a867e6.
Restored component/Session/minutes/official-reauth/API neighbors pass47/658,
seed56973, 4.41s. No fault remains and all previous assertions are retained.

The actual persisted-phase callback verifies a saved revision, attestation, attested
minutes and lifecycle event before raising; the enclosing transaction restores their
complete graph and unconsumed confirmation. Removing the replacement permits that
same confirmation to perform the real attestation successfully. This is an injected
persistence failure, not an observed incident. The unchanged real approval browser
journeys pass3/131, seed44011, 19.32s: human confirmation/handoff, editable review,
attestation, corrected final lock and subsequent member HTML/real PDF, plus direct
Adjutant and later officer-expiry member navigation. No new browser TTL-boundary or
near-midnight policy claim. Final committed full suites and CI remain pending.
