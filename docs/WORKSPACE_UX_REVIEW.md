# Membership and Buddy Checks UX review

October 12, 2026. Scope: the Membership workspace introduced after the admin hub
redesign, the Buddy Checks browser companion, meeting attendance, address review,
and personal app connections. Use [the design](BUDDY_CHECKS_WORKSPACE_DESIGN.md)
and [the member guide](BUDDY_CHECKS_WORKSPACE.md) for intended flows.

## Placement and workflow inventory

| User looks for | Previously | Current placement |
| --- | --- | --- |
| Welfare call suggestions and preparation | Mobile API only | Buddy Checks home and Find a member |
| Their saved checks across members | Buried in individual Membership records | Your check history, shared with the mobile app |
| Agreed callback work | Fragmentary renewal/assignment projection | Your callbacks and a direct management page |
| Deferred suggestions | Mobile API only | Deferred suggestions with restoration |
| Renewal calls and payment verification | Unclear “Member follow-up” landing | Membership task directory → Renewal follow-up |
| A volunteer's actual assignments | Mixed officer and renewal language | Your assigned members and drive instructions |
| Record a contact | Large form before history | Focused entry page, reached from the member's next step |
| Membership history and receipts | Below a long entry form | Visible history with named payment entry disclosure |
| Mailing address review | Floating footer control | Beside the member's contact information, with a return link |
| Meeting attendance evidence | Floating button above renewal filters | Buddy Checks coordination and the relevant Meeting |
| Print call sheets and finish a drive | Closure mixed with routine actions | Printing beside assigned work; a separate Finish the drive section |
| Disconnect the iPhone app | Stray Profile button and numbered sessions | Profile → Connected apps; short-lived and remembered connections |

## Review boundaries

Personal Buddy Checks preserve caller-note ownership and the current pilot gate.
Membership managers keep their existing broader Membership history. No role or
permission grants change. Earlier date-only callback notes are labelled as contact
facts separately from timed callback appointments. Unknown contact/attendance
coverage stays unknown. This review does not claim an audit of every older screen.

## Rendered critique

Reviewed synthetic browser captures at 1400px, 900px, and 390px. Membership and
Buddy Checks use the admin hub's bounded destination lists and semantic groups.
Next-step status stays beside its action; phone rows stack in task order. Focused
contact/callback forms retain their values on errors. Member history is visible
without scrolling through entry fields, and address review sits beside contact
information. Phone attendance rows support long names without squeezed labels.

The first review exposed an extra desktop navigation row. Adjusted spacing, while
keeping 16px labels and 48px targets, and verified all eight administrator
navigation destinations fit one row. The later menu revision below supersedes this
eight-destination arrangement. Destination focus rings stay inside clipped
row containers. New form controls meet 44px target and 16px type floors. Phone
layouts have no horizontal page overflow. Profile groups app connections between
sign-in controls and agent access; both short-lived and remembered connection
revocation remain available.

The Meeting invitation field now says **Who can attend**, distinguishing invitation
policy from the separate General-member attendance register. Welfare drive rows no
longer present renewal standing as the next welfare task. Assignment administration
is secondary to **Open caller work**, with closure in a separate named section.

## Validation evidence

- Browser group: 19 workflows, 3527 assertions, no failures/errors/skips. Includes
  the existing admin hub, payment/summary/returned-paper flows, attendance revisions,
  normal and remembered OAuth consent, connection revocation, and pilot removal.
- Later focused browser check: 3 workflows, 200 assertions, no failures/errors/skips,
  including destination keyboard focus, 44px targets, full administrator navigation,
  phone form recovery, callback changes, and desktop/tablet/phone captures.
- New integration checks: 7 tests, 105 assertions, no failures/errors/skips. Web
  checks/callbacks appear through mobile reads; retries save once, corrections retain
  originals, stale submissions retain values, and ownership/pilot/paused-contact
  boundaries deny access. Earlier contact correction fields preserve their original
  channel/result and date-only callback precision.
- Clean HEAD baseline (2c0fa62): the new workspace detector fails on the missing
  `/buddy-checks` page with HTTP 404. It passes with the workspace implemented.
- Brakeman: zero errors and warnings. Focused RuboCop and `git diff --check` pass.
  Documentation link/fence checks pass.

### Timezone findings during broad checks

The initial default-UTC full suite ran 1479 tests with 20 failures at the UTC/Post
calendar-day boundary. Representative role/expiry failures reproduce unchanged in
clean HEAD. Running with Post 165's configured Central time removed those role
failures and exposed one existing Organization test that hard-coded a UTC fallback.
That test now explicitly exercises both configured UTC and Central time against a
Honolulu request context; its original midnight/DST behavior checks remain. Five
Organization tests pass under UTC. General role tests using the application date
rather than the saved Post date remain a test-maintenance follow-up; the product's
Post-date authority checks are unchanged.

Final full suite: `APP_TIME_ZONE=America/Chicago PARALLEL_WORKERS=1 bin/rails test`
passed with **1480 tests, 15033 assertions, zero failures/errors/skips**. The log is
`/tmp/buddy-workspace-full-final.log`. Subsequent focused Meeting/workspace checks
passed with 16 tests and 211 assertions, including the invitation-label clarification.
The browser logs are `/tmp/buddy-workspace-browser-final.log` and
`/tmp/buddy-workspace-browser-refinement.log`.

These are local synthetic results. They do not claim a production release or native
iPhone device verification.

### Artifacts and boundaries

Captures: `/tmp/buddy-workspace-redesign-screens/`. The independent agent-browser
walkthrough uses a separate named synthetic database, follows sign-in and the phone
Menu, searches for a member, opens preparation, and locates Profile → Connected apps.
Final whole-page previews are `manual-buddy-home-desktop.png` and
`manual-buddy-home-phone.png`. The review browser and server were stopped afterward.

Ordinary and browser suites use separate named test databases when running together.
No development or production member data was read/copied/reset. No paid AI call,
external message, commit, push, or deployment was performed by this change. Concurrent
mobile backend/sign-in work and its handoff documents remain separate.

## Menu and separate workspace review

The [October 12 menu design](MENU_AND_WORKSPACE_DESIGN.md) separates Post duties
from application settings. Desktop keeps five member destinations. Menu carries
Buddy Checks and assigned calls under Your work, Officer tools under Post duties,
Administration under Application settings, and Profile/Sign out under Your account.
People with both workspace authorities see both hubs. A current 1st Vice Commander
reaches Membership from Officer tools; scoped callers reach their assigned work
directly without officer access. Old scoped `/admin` bookmarks redirect to Officer
tools. Operational back links return to Officer tools, while settings pages return
to Administration.

Reviewed actual synthetic captures at desktop, tablet, 390px, and short 320px widths.
Administration balances roster work with access, connections, and maintenance.
Officer tools retains the admin redesign's whole-row destinations, task headings,
and bounded measures. The short-phone review exposed an off-screen menu edge in
the presence of a scrollbar; the corrected width retains an inset. The independent
390-by-450 browser check reaches Sign out with Arrow Up, scrolls Menu by 381px,
and keeps its bottom at 420px. Escape returns focus to the Menu button. Menu targets
are at least 44px and interactive text at least 16px.

Final affected browser group: **26 workflows, 3589 assertions, no failures/errors/skips**.
It includes actual hub navigation, ordinary/pilot/assigned/first-vice/admin access,
ended offices and removed grants in established sessions, leaf-page denial, desktop
focus order, short-phone sign-out, existing pending/completed official-action sign-out,
and Membership/Buddy Checks tasks. Log: `/tmp/menu-workspace-browser-complete.log`.

A private code copy removes only the hidden-link focus filter. The new desktop
keyboard detector fails with expected `/buddy-checks` versus actual unfocused link
(`nil`), then passes after restoration: **1 workflow, 57 assertions**. The shared
worktree was not faulted. Logs: `/tmp/menu-workspace-fault.log` and
`/tmp/menu-workspace-restored.log`. Final captures: `/tmp/menu-workspace-screens/`.

Focused RuboCop: **15 files, no offenses**. Locked Brakeman 8.1.0 scan:
**zero errors and security warnings**. The wrapper's latest-version check could not
write its sandboxed gem cache, so the scan used `bundle exec brakeman -q` without a
dependency update. Documentation links/fences and `git diff --check` pass.

Final full Rails run: `APP_TIME_ZONE=America/Chicago PARALLEL_WORKERS=1 bin/rails test`
passed with **1484 tests, 15101 assertions, no failures/errors/skips**. This includes
updated navigation and scoped-hub expectations while preserving permission, ownership,
officer-date, and official-action checks. Log: `/tmp/menu-workspace-full-final.log`.
JavaScript syntax and the final diff whitespace check also pass.

Development preview is running with Rails in development and the Tailwind watcher,
bound to **0.0.0.0:3000**. Both `/up` and `/session/new` return **HTTP 200** through
`http://192.168.37.41:3000`. The local Buddy Checks feature flag is enabled; existing
pilot grants still control access. Foreman 0.90.0 was installed by `bin/dev` as its
missing launcher dependency; application dependency files are unchanged.

Startup found four existing pending Buddy Checks/app-session migrations. Their
inspected `up` paths add tables, fields, evidence triggers, and wider capability
constraints. Applied those migrations to the development database to serve current
HEAD; existing member records and grants were retained. The schema dump went to
`/tmp/legion-member-workspaces-development-structure.sql`, preserving tracked schema
files. The temporary Procfile uses an explicit project root and a separate PID file.
No production operation, commit, or push was performed.

## Buddy Checks as check-ins and care, separate from renewals

Andre clarified that Buddy Checks concern caring for each other and sometimes suicide
prevention. County receives one monthly count of checks performed where the person
was reached. The [coordination design](BUDDY_CHECK_COORDINATION_DESIGN.md) and updated
[guide](BUDDY_CHECKS_WORKSPACE.md) define the resulting workflows.

Menu → Your work → Buddy Checks now supports a separate Post activity list, member
Buddy Check history, internal care coverage, and county reporting. A coordinator
without pilot calling access lands on Post activity. County reporting has a named
month/year picker and one count; no-answer/message/wrong-number attempts, administrative
reviews, care reviews, callback management alone, dues/welcome entries, and superseded
revisions are excluded. It uses the actual Post-local contact date, not entry date.
Caller notes, member identities, and care concerns stay out of the county summary.

Internal coverage shows recorded conversations, known meeting attendance, no-contact
requests, and human-entered care follow-up. Missing evidence remains unknown; an
absence alert requires two complete, explicit covered absences. Newer incomplete or
present revisions interrupt it. Care concerns sort first by review date, with a due
review link from Post activity. Care notes require an owner and review date, preserve
attributed revisions, reject stale updates and changed retries, and stay outside
caller pages, mobile responses, general profiles, and county reports. Disabled/expired
coordinators lose access. No-contact requests pause routine Buddy outreach. Buddy
caller/drive pages use Buddy labels and omit dues and renewal-year controls.

Reviewed rendered 1400px and 390px pages using both browser captures and an independent
synthetic browser walkthrough. Whole-row navigation, readable controls, stacked phone
records, and the county's single large number retain The 1919 system. The native month
input was replaced by a month list and year field after a browser selection problem.
Private coordinator pages use HTTP no-store and disable Turbo snapshots.

Verification:

- Full ordinary suite: **1491 tests, 15227 assertions, no failures/errors/skips**.
  Log: `/tmp/buddy-coordination-full-final.log`.
- Final affected browser group: **23 workflows, 3514 assertions, no failures/errors/skips**.
  Real synthetic mobile API writes appear in Post activity/history and monthly counts.
  Includes invalid care-form recovery, resolution/history, role loss, contact preference,
  and existing payment, paper-call, attendance, and menu workflows.
  Log: `/tmp/buddy-coordination-browser-verified.log`.
- After final presentation refinements: **60 tests, 702 assertions, no failures/errors/skips**.
  Log: `/tmp/buddy-coordination-focused-final.log`; the last extra-care/owner boundaries
  are in `/tmp/buddy-coordination-last-boundaries.log`.
- A newly prepared named test database passed **19 tests, 171 assertions** for the
  migration/schema-loaded database guards and coordination workflows. The existing guard
  inventory now includes the additional append-only care table. Direct SQL update/delete
  of care reviews is rejected while originals survive. Log:
  `/tmp/buddy-coordination-fresh-guards.log`.
- A private code copy removes only the reached-result filter from county counting. The
  detector fails with **expected 2, actual 5**; restoration passes **1 test, 20 assertions**.
  Logs: `/tmp/buddy-coordination-fault.log` and `/tmp/buddy-coordination-restored.log`.
  The shared worktree was not faulted.
- Focused RuboCop: **19 files, no offenses**, plus clean final refinement lint.
  Locked Brakeman: **zero errors and security warnings**. Documentation references,
  code fences, and final diff whitespace checks pass.

Captures: `/tmp/buddy-coordination-screens/`. Review server/browser were stopped.
The development server remains on **0.0.0.0:3000**, with LAN health HTTP 200 and an
anonymous Buddy Check workspace request correctly redirecting to sign-in. The one
new development migration adds only the care-update table/indexes/constraints/guard;
member records are retained, and development schema output was redirected to `/tmp`.
The checked-in SQL schema was generated from test state. No production operation,
external message, paid AI generation, commit, or push was performed.
