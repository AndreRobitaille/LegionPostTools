# Officer workflow walkthroughs

Use three reusable browser personas to explore whether LegionPostTools supports real
American Legion work: Commander, Adjutant, and technical administrator. Each represents
a fictional person with the application's current authority; there is no new bot role.

## Pilot design

Run a small shared meeting scenario before expanding the catalog. Each actor receives
their role brief and factual situation, not a route list or click recipe. Separate
browser sessions preserve the handoff. A supervisor prepares synthetic records and
checks persistence, provenance, and later reads independently of the actor's account.
The browser actors must not inspect application source, tests, database, or `/api` to
solve a task. Record assistance rather than silently supplying the next click.

The first pilot covers preparing an agenda, Commander-to-Adjutant minutes handoff,
Adjutant edits and attestation, later meeting corrections, and officer turnover.
Include an Adjutant-originated draft to check that Commander handoff is optional.
Use desktop and 390px phone widths, and return in a fresh browser session between
stages. A member account provides the independent reader's view.

Current [minutes policy](../../MINUTES_APPROVAL_AND_ATTESTATION.md) governs the
scenario. Commander drafting and handoff do not create a repeated approval gate.
Adjutant attestation captures exact text. The meeting body's later approval and
correction decision are distinct. Final minutes remain immutable. The broader
description in `docs/USERS.md` does not override this lifecycle policy.

Visual review follows The 1919 system. Evaluate whether its hierarchy, readable type,
bounded measures, focus, status, and nearby action help the actor's job. A proposed
departure needs a concrete observed problem, alternatives, and a reason. This pilot
changes no product UI; report findings before choosing fixes.

## Run locally

Use the repository's locked Ruby/bundle, local PostgreSQL, and Chromium. The wrapper
always selects `test` and the dedicated `legion_post_tools_role_walkthrough_test`
database, with `APP_TIME_ZONE=America/Chicago` matching the fictional Post. It never
resets a database. Preparing again preserves an existing pilot.
This provisions one persistent scenario. After completion, inspect its saved state and
define the next factual task; do not repeat initial editing tasks against locked records.

```sh
bin/role-walkthrough prepare
bin/rails tailwindcss:build
bin/role-walkthrough serve
```

The server binds `0.0.0.0:3095`. `ROLE_WALKTHROUGH_PORT` can choose another port.
`ROLE_WALKTHROUGH_OUTPUT` chooses the local evidence directory (default
`/tmp/legion-role-walkthrough`). Keep it outside Git: it includes synthetic login
emails and session evidence. Stop the owned server after the walkthrough.

The server uses the real email sign-in and confirmation screens. Mail is captured
locally under `mailbox/<actor-email>.txt`; only fictional `@example.test` recipients
are accepted. Only email jobs execute. Other queued work is explicitly blocked,
and automatic Endeavor AI history is disabled. This establishes the browser flow
with an offline email substitute, not live delivery or provider acceptance.

Read `scenario.json` for the generated dates and task facts. Give each actor the
matching [Commander](commander.md), [Adjutant](adjutant.md), or
[administrator](administrator.md) brief. The supervisor keeps `baseline.json` and
does not give it to the browser actors. Use separate named browser sessions; preserve
each role's synthetic authentication state outside Git when a session must resume.

```sh
bin/role-walkthrough inspect
```

`inspect` reads the actual saved records, actor capabilities, revisions, and lifecycle
events. Compare them with the facts and expected outcomes, then repeat the relevant
read through the browser. It does not repair records or turn an actor's narrative
into a passing result. Its stored-payload digest supports later snapshot comparisons;
JSONB key ordering means it is not the original document-capture digest. Follow
[testing guidance](../../TESTING.md).

## Evidence and interpretation

Use the [observation template](observation-template.md). Keep task completion,
assistance, usability observations, saved-state checks, and proposed changes separate.
Capture before/action/after screenshots and a repro video for an interactive finding;
one screenshot suffices for a static visible issue. Reproduce before calling a
candidate a defect. Tooling failures are not application findings.

Bring a target into the viewport before a browser-tool click and refresh element
references after navigation. Start a recording before filling an unsaved form, then
reapply the intended viewport and inspect the current page: recording startup can
reload the browser context. Preserve each actor's real auth state before closing an
interactive shell when the sandbox does not keep browser daemons alive between calls.

These agents can identify workflow and navigation problems. Their ability to recover
does not establish that an infrequent officer or a person with low computer confidence
can do so. Validate promising changes with actual officers using the same factual
tasks, and record where their needs differ from the simulation.

The [October 11 pilot report](PILOT_2026-10-11.md) records completed stages, independent
checks, observed recovery, and questions for actual officers.
