# Application-map maintenance and evidence

Initial baseline: `5adda175d67e9603f58fdf8574ad6f7a0313d6b9`, October 10, 2026.
Entry point: [Application map](../APPLICATION_MAP.md).

## What this discovery establishes

This pass inspected repository routes, controllers and authorization predicates,
current governing behavior documents, record relationships/lifecycles, navigation,
templates, JavaScript controllers, jobs and selected services/schema protections.
The [source ledger](SOURCE_INVENTORY.md) accounts for every file in the scoped UI
discovery directories. The [interface inventory](INTERFACES.md) groups them by job;
62 [workflow contracts](WORKFLOWS.md) state independent behavioral targets.

The ledger is a completeness aid for finding interfaces, not proof that every
branch or every rendered control was inspected dynamically. A public method can
be unrouted, a view can be rendered by another controller, a partial can own an
important control, and mounted Rails engines contribute paths absent from explicit
application route declarations. These require compiled-route and browser follow-up.

No feature code, existing tests, database, production configuration, official record,
external account, credential, or scheduled QA automation was changed by this pass.
The test suite was not audited for workflow coverage or assertion effectiveness.
There was no paid AI call or transcript replay.

## Evidence statuses

Keep these fields separate when extending a contract or starting QA:

| Field | Allowed evidence / initial state |
| --- | --- |
| Intended behavior | Current governing policy, explicit user decision, or marked open decision; generic software examples are not Post requirements |
| Source discovery | Source path + baseline SHA; all mapped contracts initially source-located |
| Runtime observation | Environment, revision, synthetic actor/data, action and actual outcome; initially not performed |
| Test association | Exact test path/name, level, fixture and assertions; initially not assessed, not “untested” |
| Execution/discovery | Exact command, environment, runner/CI invocation and results; no current suite result from this pass |
| Defect detection | Specific controlled fault, isolation, failing assertion/test, restoration and clean rerun; initially not assessed |
| Production evidence | Deployed SHA/configuration and authorized live observation; initially not inspected |

“Located,” “covered,” “passed,” and “detects the failure” are different claims.
Preserve failed/blocked observations; never upgrade evidence based on test count,
an HTTP 200 alone, or a previous document's historical verification section.

## Source discrepancies and follow-up questions

These are discovery findings, not reproduced runtime defects or an authorized fix
list. Preserve the expected behavior separately until investigated. No question
here requires delaying this documentation reference.

| ID | Expected or conflicting statement | Current evidence | Next validation |
| --- | --- | --- | --- |
| G-01 | [Meeting foundation](../MEETING_FOUNDATION_AND_MEMBER_ARCHIVE.md) and [Roles](../ROLES.md) call for member/delegate parity in private Meeting reading | Member [HTML](../../app/controllers/meetings_controller.rb) requires authentication only; [API Meeting reads](../../app/controllers/api/meetings_controller.rb) require `manage_agendas`, `manage_minutes`, or `view_internal_records`. [API minutes](../../app/controllers/api/meeting_minutes_controller.rb) also represents an officer workspace, not ordinary member revision reading | With synthetic baseline member/session/token, compare archive/document contracts, actual API response and handbook; decide/fix desired parity separately from restricted officer evidence |
| G-02 | Older [officer workspace table](../OFFICER_WORKSPACE_EXPERIENCE.md) gives Commander only agenda/handoff and Adjutant no recorded-meeting-approval capability | Current [preset](../../app/services/american_legion_post_preset.rb) gives both drafting and `record_minutes_approval`; Commander also handoff, Adjutant attestation. [Current minutes rules](../MINUTES_APPROVAL_AND_ATTESTATION.md) describe either officer preparing/recording approval | Treat preset as source and current minutes rules as policy; inspect dated migrations/configuration before asserting actual installation grants; reconcile older table in a separate scoped doc update |
| G-03 | Transcript form promises deletion after membership approval with 30-day recovery window | [Form](../../app/views/admin/meeting_transcripts/new.html.erb), [model](../../app/models/meeting_transcript.rb), [schema](../../db/structure.sql) store retention/purge metadata. No purge controller/job/scheduler or approval-triggered purge was located in app/config | Synthetic approval + elapsed recovery-time investigation; distinguish planned retention mechanism from actually enforced deletion; do not promise deletion from a stored enum |
| G-04 | [Minutes lifecycle](../MINUTES_LIFECYCLE.md) protects Meeting time/body/place after final approval | [Meeting heading guard](../../app/models/meeting.rb) checks agenda locks and returns early without agenda; no final-minutes condition located. [Database trigger](../../db/migrate/20260902010100_protect_membership_approved_minutes.rb) protects `meeting_minutes`, not `meetings` | Try synthetic finalized Meeting with/without agenda and after agenda reopening; assert immutable revision and occurrence metadata separately. Potential missing occurrence safeguard, not a claim that signed revision changes |
| G-05 | Older [agent minutes parity spec](../superpowers/specs/2026-08-31-agent-minutes-api-parity-design.md) excludes identity-bound delegated approval/attestation; [operator brief](../agent-operator-skill.md) still calls website snapshots anonymous | Current [Roles](../ROLES.md), [minutes rules](../MINUTES_APPROVAL_AND_ATTESTATION.md), [API handoff](../../app/controllers/api/minutes_approvals_controller.rb)/[attestation](../../app/controllers/api/minutes_attestations_controller.rb), and [website connections](../WEBSITE_CONNECTIONS.md) supersede those statements | Keep current exact delegated authority and website credential requirements in this map; recheck generated handbook and reconcile old documents separately |
| G-06 | Referenced Meeting Type cannot be removed and failure should be understandable | [MeetingType](../../app/models/meeting_type.rb) has `restrict_with_exception` references; [controller destroy](../../app/controllers/admin/meeting_types_controller.rb) calls destroy and then unconditional success notice, with no local restriction rescue | Submit delete on synthetic referenced type; inspect error/status and preserved template/dated content, not only model restriction |
| G-07 | Deleting dated content must preserve historical minutes and give clear restriction feedback | [DatedAgendaItem](../../app/models/dated_agenda_item.rb)/[section](../../app/models/dated_agenda_section.rb) restrict linked minutes deletion. [HTML agenda destroy](../../app/controllers/admin/dated_agendas_controller.rb) has no local rescue; [API](../../app/controllers/api/dated_agendas_controller.rb) rescues RecordNotDestroyed but not DeleteRestrictionError | Exercise delete of synthetic agenda/item/section referenced by minutes; compare UI/API response and retained copies. Do not assume optional lineage means automatic detachment |

Other explicit gaps: formal amendments, transcript purge actions, full-roster CSV
export, general document/archive management, recurrence/registration/volunteer
scheduling, post-setup installation settings, and general Meeting Body/Person CRUD
are not available mapped workflows. Existing roadmap text is not an implementation
claim. Publication activation, grant assignments and provider availability are
installation facts that remain unverified.

## Initial verification and limits

`RAILS_ENV=test bin/rails routes --expanded` was attempted to inspect compiled
routes. It could not boot: Bundler::GemNotFound reported missing locked dependencies,
including `pg 1.7.0`, `lexxy 1.0.1`, `openai 0.103.0`, Capybara and Selenium. The
source route declaration was read instead; no compiled route count is claimed.
Dependency installation was not needed to validate these documentation changes.
There was no database preparation/reset or development/member-data access.

Documentation verification passed across five map documents: 1,060 local link
targets, 451 workflow anchors, and 62 unique contracts with all six required fields.
Every file in six source directories is represented; all workflow references and
37 explicit route-controller references plus resource declarations resolve to
source. Markdown table columns/fences and whitespace checks passed; README diff
review and `git diff --check` passed. These checks establish document consistency,
not compiled route behavior. No Rails suite, browser smoke, security scan or live
release is claimed for this documentation pass.

For follow-on QA, [CI](../../.github/workflows/ci.yml) currently declares ordinary
Rails tests followed serially by `bin/rails test:system`; ordinary `bin/rails test`
does not include system tests. [System setup](../../test/application_system_test_case.rb)
uses the test database and real magic-link path. This is runner configuration
discovery, not proof that those tests ran or detect each mapped defect.

## Maintaining the reference

Use the standing [Testing and workflow validation](../TESTING.md) method for behavior
changes and test-quality reviews. The [October 11 completion report](../testing/OVERNIGHT_HANDOFF_2026-10-11.md)
records the subsequent scoped review; the initial discovery and handoff below remain
dated evidence, not an assertion that those follow-up tasks are still outstanding.

1. Start with the user job and governing policy, before reading a proposed implementation/test. State new behavior and unresolved decisions distinctly.
2. For a behavior/permission/navigation/async/publication change, update its interface row and workflow contract, including denied/stale/interrupted cases and later interactions. Keep stable IDs; retire old IDs with reason/replacement instead of silently reusing them.
3. Reconcile source-route/controller/view/Stimulus/job additions with the source ledger. Add every new file or explicitly classify it as technical/planned; a file count alone does not establish behavior completeness.
4. Update baseline SHA/date for the reviewed snapshot and record scope. Do not mark unrelated contracts runtime-verified because one changed workflow passed.
5. Critique expectations against user/product policy and observed behavior. Preserve discrepancies; do not edit expected behavior merely to make source/tests agree.
6. When independent review is requested, give the reviewer contracts and product decisions first. They should trace actual controls/state/errors and assess tests without relying on the implementing agent's claims. A separate agent is optional, not evidence of independence by itself.

Useful discovery commands (read-only; use test environment for Rails):

```sh
git rev-parse HEAD
rg --files app/controllers app/views app/javascript/controllers app/jobs
rg -n 'before_action|require_capability|require_any_capability' app/controllers
rg -n 'def |STATUSES|member_visible|editable' app/models
RAILS_ENV=test bin/rails routes --expanded
```

Source ledger updates must keep relative links from this directory, declared
methods separate from compiled routes, and exact per-file workflow classifications.
It deliberately does not contain private data or copies of the entire source code.

## Handoff to test-quality review

The next initiative is a separately scoped coverage/effectiveness audit, beginning
with P0 authentication/authority and official-record/publication transitions, then
P1 persistence/recovery. Do not automatically generate another large test suite.

For each workflow **variant**, record:

| Workflow / variant | Expected outcome source | Existing test + level | Actually executed? | Meaningful persisted/visible/subsequent assertions | Mocked boundaries | Missing/weak evidence | Controlled fault result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AUTH-04 / session referenced by historical confirmation | Current sign-out/session policy | Not assessed | Not run here | Sign-in return; protected URL denied; historical audit survives and confirmation cannot be reused | Not assessed | Browser control/Turbo/CSRF/foreign-key combination must be examined | Not attempted |

A browser-level path is valuable where the real rendered control, JavaScript,
cookies/redirects or PDF interaction matters. Integration tests can establish
persistence and policy across components; model/service tests support development
rules. Use the lowest sufficient level and strengthen it when realistic boundary
failures remain hidden. Never count setup-helper login as sign-in coverage or a
mocked PDF/provider success as proof of rendering/provider quality.

Fault injection, if later authorized, belongs in an isolated test-only checkout or
temporary reversible patch with approved synthetic data. Define the fault and the
expected failing assertion before injecting it, run the relevant discovered tests,
restore exactly the experiment's changes, and prove clean behavior afterward.
Never inject into production or alter unrelated work; surviving faults indicate
an assertion/coverage gap, not permission to weaken the contract.

Recurring/nightly review remains a proposed operating model. No automation was
created. First establish review scope, map-drift detection, useful report format,
cost/runtime limits, ownership and actionable notification rules. Periodic reviews
should evaluate test effectiveness and new workflow variants, not merely rerun
tests or report unchanged passing counts.

Current schema reference updated for #86: PostgreSQL SQL schema now preserves migration-defined functions and triggers. Initial discovery above used the Ruby schema; current schema fidelity and direct-write evidence are recorded in `docs/DATABASE_SCHEMA_GUARDS.md` and the review ledger. This does not imply production verification.
