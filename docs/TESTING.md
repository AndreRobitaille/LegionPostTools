# Testing and workflow validation

TDD and focused component tests support development. Completing a meaningful behavior
change also requires checking the user's workflow against expectations derived from
current product policy, independently of the implementation and its tests. A passing
suite or increasing test count does not establish that a Post member can complete the
job, that an official record stays authentic, or that a regression will be detected.

Read this guide for meaningful behavior changes and test-quality reviews. Scale the
work to the affected behavior and risk; a documentation correction does not need a
new browser suite, and a trivial edit does not need a test that repeats its code.

## Start with the user job

Before evaluating implementation or assertions, state the expected outcome from the
current governing documentation or an explicit user decision. Use the
[application map](APPLICATION_MAP.md) to find the relevant interfaces and stable
[workflow contracts](application_map/WORKFLOWS.md). Resolve material policy conflicts
without changing expectations merely to match the code. A source discrepancy is a
candidate defect until realistically reproduced.

For each affected workflow variant, identify:

- The starting state, actor, and current authority.
- The actual action through the relevant interface, including its rendered control
  when browser behavior matters.
- The saved state and visible result, including records that must remain unchanged.
- A later read or action that proves the result survives the initial response.
- Relevant denial, stale authority, date boundary, interruption, and recovery cases.

Use concrete Post workflows. For example, after synthetic minutes become final, try
the relevant later editing path and verify that the accepted revision and protected
Meeting context remain intact. For officer turnover, reuse the existing synthetic
session or token after authority changes and verify the next request's permissions.
An HTTP success or redirect alone does not prove either contract.

## Use the lowest sufficient test level

Keep useful model and service tests for domain rules. Use integration tests for
cross-component authority, persistence, response content, and subsequent requests.
Use real browser workflows where rendered controls, cookies, Turbo, JavaScript,
layout, sign-in, or PDF delivery materially affect the outcome. Check desktop and
narrow widths for changed UI, following the project's visual design requirements.

Read existing tests before adding more. Assess assertions, fixtures, helper shortcuts,
mocked boundaries, and actual runner discovery. Strengthen a useful existing test
when it can detect the missing behavior. Do not remove or consolidate tests until
their unique defect detection is understood and preserved.

Helper-established authentication does not test sign-in. A mocked provider or PDF
success does not establish live provider acceptance or actual document rendering.
Use synthetic data and offline provider fixtures for normal automated verification;
record what a substitute establishes and what remains unverified.

## Establish regression detection

For a meaningful regression, show that the relevant assertion detects the original
failure and passes with the correction. Where that evidence is unavailable or test
quality is the subject of review, a narrowly scoped reversible fault experiment can
provide evidence: define the representative fault and expected detector first,
apply it only in an isolated test-only checkout with synthetic data, run the relevant
tests, restore the exact experiment changes, and rerun cleanly. Preserve unrelated
work throughout. A surviving fault calls for investigating the assertion or missing
variant; it does not justify weakening the expected behavior.

Fault experiments are proportionate verification, not a mandatory step for every
edit. Never inject faults into production. Local development databases can contain
real member data; use the test database and do not reset development data. Paid AI
calls, restricted transcript replay, production mutation, and official-record actions
remain subject to their explicit authorization boundaries in [AGENTS.md](../AGENTS.md).

## Report evidence precisely

Keep these claims distinct:

| Claim | Evidence |
| --- | --- |
| Intended | Current policy or explicit product decision |
| Located / reviewed | Exact source and test paths, assertions, variants, and revision |
| Executed | Exact command, environment, revision, and results, including omissions |
| Detects a regression | Original failure or representative fault, failing detector, restoration, and clean rerun |
| CI passed | Workflow and exact tested revision; runner discovery includes the intended tests |
| Production verified | Deployed revision and authorized live observation |

Report meaningful persisted, visible, and subsequent assertions, mocked boundaries,
unexplained failures, and remaining gaps. Test counts and coverage percentages are
supporting inventory, not evidence that every workflow variant works. Keep dated
discovery and review reports as history rather than treating them as current blanket
coverage or production claims.

Useful dated examples are the [workflow variant review](testing/WORKFLOW_VARIANT_REVIEW.md),
[test inventory](testing/TEST_FILE_INVENTORY.md), and
[October 11 completion report](testing/OVERNIGHT_HANDOFF_2026-10-11.md).
The [map maintenance guide](application_map/MAINTENANCE.md) describes how to update
contracts and retain discrepancies without confusing discovery with validation.

## Choose and run relevant checks

Follow the risk-based checks in [AGENTS.md](../AGENTS.md). Ordinary Rails tests and
browser system tests are separate commands: `bin/rails test` does not include
`bin/rails test:system`. Run them serially when sharing the test database, as CI does.
For changed UI, include proportionate browser and rendered visual review. For
cross-cutting authority, official-record, or release changes, broaden the checks.
For documentation-only changes, check references, Markdown structure, whitespace,
and the complete diff; rerunning local application suites is usually unnecessary.

Verify CI against the exact revision before an authorized merge. Repeat passing
checks only when subsequent changes, failures, or unresolved concerns justify it.
Neither this guide nor a passing suite grants authority to push, merge, deploy, copy
member data, or approve an official record.
