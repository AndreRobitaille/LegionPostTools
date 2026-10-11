# Officer authority across turnover

Design for #78, October 10, 2026. Current minutes approval/attestation and Roles policy
give Commander and Adjutant drafting plus later-Meeting approval recording; Commander
hands off and Adjutant attests. The standard 1st Vice Commander receives full membership
access without those meeting duties. These are independent expected duties, not values
derived from the preset constants under test. Configured positions are portable Post
policy; never infer actual production officeholders or grants from the preset.

Current source resolves dated assignments inclusively and separately from manual grants.
The older officer-workspace table omits Commander drafting and both approval-recording
duties; update it to current policy while labeling the named original installation
correction as historical context, not a verified current assignment.

## Bounded scenarios

Retain existing User/PositionCapabilityGrant component invariants, last-administrator
safeguards and assignment CRUD/foreign-scope checks. Add a small real-request matrix:
standard Commander/Adjutant draft through HTML/API, permitted and denied bearer identity
acts, actual later-approval HTML confirmation path; 1st Vice membership reads without
meeting/technical/publication duties. Do not create permanent per-user position grants.

Use one already-issued token through future start, start/inclusive end, next-day expiry,
inactive position and harmless display rename. A formerly permitted write must become
denied without changing records, while member reading remains. Explicit manual drafting
exceptions survive turnover but must not preserve unrelated official, roster, calendar,
publication or private-copy authority. Historical/honorary office alone grants nothing.

Strengthen the existing real browser approval journey to use actual configured current
offices rather than duplicate manual duties, retaining all its confirmation, correction,
navigation and PDF assertions. Add a narrow subsequent access-loss check where needed.
The visual direction stays the existing 1919 Officer tools/member navigation with plain
denial feedback; inspect desktop and narrow views during these checks.

First run on unchanged resolver/preset to distinguish a documentation/coverage discrepancy
from a runtime defect. An isolated fault retaining expired position capability must fail
the real subsequent write/refusal assertion; restore exact bytes and rerun clean.
Full ordinary/system suites, lint/security and exact-SHA CI run before any code PR merge.
Use synthetic test data only; no production assignment inspection, paid AI or deployment.

## Focused evidence and remaining verification

The unchanged resolver passes the three ordinary duty matrices; a fourth exact retry
revealed private cached minutes after expiry (#92). Shared current-authority replay
checks repair that separate path. Both officers also complete actual later-Meeting
approval through a human email confirmation with no manual grant. Expanded neighboring
API/role/confirmation tests pass 198 / 2095 / 0. After reordering denied writes to inspect
persisted attributes before the response, removing the end-date predicate fails both
officer matrices on changed headings (2 / 73 / two failures); exact User bytes restored.
Restored focused contracts pass 26 / 444 / 0 (seed 64008, 5.81s).

Configured-office browser flow plus subsequent expiry/refusal/member navigation passes
3 / 131 / 0 at desktop/390px, with all original lifecycle/PDF assertions retained.
The wider Post/server date boundary is separately pending in #93. No current production
officeholder/grant conclusion follows from these synthetic fixtures. Full final-candidate
serial suites and exact-SHA/actual-main CI remain required before merge; see the
[review ledger](testing/OVERNIGHT_REVIEW_2026-10-10.md).
