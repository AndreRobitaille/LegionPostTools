# Agent Instructions

Read this file before making code or documentation changes.

## Scope and Working Agreement

This is the shared project entry point for all coding agents. Read task-relevant
documentation and nested guidance; do not load every design or skill. User instructions
control task scope. Skills guide implementation, not additional authority or approval
ceremonies. Runtime permissions still apply.

- Carry requested changes through implementation and proportionate verification. Make
  routine, reversible choices using project context; do not stop at a plan or ask again
  for authorization already given in the session.
- Reviews and diagnoses are read-only unless changes are also requested. Ask only for a
  material unresolved product/architecture decision, missing authority, or an enforced
  permission requirement. Complete independent authorized work first.
- Inspect the worktree before editing. Preserve unrelated changes and untracked files;
  never reset, stash, overwrite, or stage them to make a check or release pass.
- Commit, push, deployment, external messages, and destructive data operations need
  authorization covering that action. Authorized push-and-deploy includes the narrow
  commit described below. Engineering authority never implies official-record approval.
- Scale planning to risk. Small fixes need a brief rationale, not a separate ceremony.
  Meaningful behavior changes need the design work below; an already authorized design
  does not require another approval pause before implementation.
- Work locally by default. Use subagents only when requested or explicitly required by
  applicable guidance, with bounded independent tasks; no mandatory delegation/review loop.
- Prefer concise, connected prose. Report outcomes, checks, and material limitations.
  If guidance blocks work, identify the exact file and rule rather than inventing a gate.
  In documentation, preserve known American Legion context and concrete requirements
  rather than replacing them with generic speculation about what users might want.

## Project Identity

LegionPostTools is American Legion software. It is specifically for American Legion posts and, where useful, the American Legion Family. Do not reframe it as generic nonprofit software.

The first real installation is Robert E. Burns Post 165 in Two Rivers, Wisconsin. Use Post 165 as grounding context, but do not hard-code Post 165 names, numbers, locations, officer rosters, URLs, or assumptions into application behavior.

## Core Product Principles

- Meeting records are the first-class workflow.
- Authenticity matters more than convenience once records become official.
- Accepted official minutes are immutable. Later corrections must be later amendments or later meeting records, not edits to accepted minutes.
- Before membership approval, corrections use audited reopen, Commander approval for
  attestation, and different-person Adjutant re-attestation. Preserve immutable revisions
  and events. See `docs/MINUTES_APPROVAL_AND_ATTESTATION.md` for current behavior;
  later amendments remain planned, not an available editing shortcut.
- AI may draft, organize, or suggest. Humans approve, attest, accept, and remain the authority.
- Users may be older or have low computer confidence. Prefer guided, plain workflows over clever interfaces.
- Favor continuity across officer turnover and committee work.

## Technical Principles

- Use Rails conventions unless there is a strong reason not to.
- Prefer boring, maintainable code over clever abstractions.
- Keep architecture simple. No microservices, Kubernetes, or broad infrastructure unless explicitly requested.
- Keep the app configurable for other American Legion installations.
- Avoid premature SaaS or multi-tenant architecture.
- Keep rich text inside structured records. Do not turn core meeting data into one large unstructured document.

## Current Stack

- Ruby on Rails 8.1.
- PostgreSQL.
- Hotwire/Turbo and importmap.
- Tailwind CSS.
- Action Text.
- Lexxy as the Action Text editor; check `Gemfile` and `config/importmap.rb` for versions.
- Active Storage.
- Solid Queue.
- Docker and Kamal for deployment.
- Passwordless authentication with passkeys and magic links.

## Design Before Implementation

Every feature requires deliberate product and UX design work appropriate to its scope. For meaningful product changes, write or update a design/spec before implementation. This is especially important for meeting workflows, official records, AI drafting, permissions, deployment, or user-facing flows.

Do not jump directly from idea to code when the change affects product behavior or long-term architecture.

For every feature that adds or changes user-facing UI, invoke an available frontend or visual design skill while planning and implementing it. Record the intended visual direction before coding, follow the established visual system, and critique the rendered result at desktop and narrow widths before calling the feature complete. Design is part of implementation, not optional polish after the feature works.

Shared design requirements: preserve design intent when simplifying implementation.
Follow The 1919 system in `docs/superpowers/specs/2026-07-11-visual-design-system-design.md`.
Readability floors are 16px for body/interactive text, 14px for secondary text, and 13px
for labels; no meaningful text below 13px. Prefer larger type over density.

## Local Development Servers

The developer typically works from a different machine than the one running the app. Bind any development server to `0.0.0.0` (not `127.0.0.1`/`localhost`) so it is reachable off-box. For `bin/rails server`, use `-b 0.0.0.0`. This applies to Tailwind/asset watchers, preview servers, and any tooling that serves over HTTP.

## Verification

Before claiming work is complete, run relevant checks and report exact results.

Choose checks for affected behavior; the commands below are not a mandatory suite for
every edit. Documentation/configuration changes need parsing, reference checks, and diff
review. Code changes need relevant existing tests and focused lint. Broaden to full-suite,
security, and browser checks for cross-cutting, authorization, official-record, or release
changes. Add tests for meaningful behavior/regressions, not a repetition of a trivial edit.
Repeat passing checks only for subsequent changes, failures, or unresolved concerns.

Common checks:

```bash
bin/rails test
bin/brakeman
bin/rubocop
bin/bundler-audit
```

For browser-visible flows, also run a browser smoke test when practical.
Report blocked or omitted checks honestly. Paid AI generation or replay of restricted
transcripts requires explicit authorization; use synthetic offline provider tests for
configuration changes. Do not apply generated minutes automatically.

## Deployment Constraints

Production is expected to run on a Hetzner Cloud VPS that already hosts another Rails/Kamal application. Do not assume LegionPostTools is the only application on the server.

Use unique names for Kamal service names, Docker image names, databases, volumes, and other shared infrastructure resources.

The Hetzner VPS throttles repeated SSH connections heavily. Before running Kamal or other SSH-heavy production operations against that server, set up a persistent SSH connection/tunnel/control master and route the work through it. Tear the persistent connection down when the production work is finished. Do not run repeated fresh SSH/Kamal commands directly against the production box.

Codex's restricted command sandbox can expose root-owned host files under `/etc` and `/usr` as `nobody:nobody`. OpenSSH 10.5 rejects that synthetic ownership with `Bad owner or permissions on /etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf`. For Codex sessions, run SSH, Kamal, and `bin/sync_prod_db` with host access outside the restricted sandbox. Confirm ownership outside the sandbox before diagnosing a host permissions problem, and never `chown` system SSH files based only on their sandbox-visible ownership.

For Post 165 releases, do not assemble the SSH/Kamal workaround ad hoc and do not run
`bin/kamal deploy` directly from an agent session. Use the repository release entry point:

- `bin/release check` verifies the host SSH control master, Kamal proxy transport, and
  remote Docker builder without changing production.
- `bin/release push` pushes the current branch and verifies GitHub's exact SHA.
- `bin/release deploy` requires a clean worktree and an exact pushed HEAD, then deploys,
  verifies the running revision and public health, and closes the control master.
- `bin/release push-deploy` performs the last two operations together.

When the user explicitly authorizes "push and deploy," stage only the intended files,
commit them, and run `bin/release push-deploy`. Do not ask again merely because Git, SSH,
Docker, or Kamal needs host access. Destructive production data work still requires its
own explicit authorization.

## Documentation Map

This map is a routing aid, not a reading checklist. Dated specs and roadmap entries are
design/history, not commands to execute, install Superpowers, commit, or deploy. Verify
implementation claims against current code/tests. Current lifecycle, access, and deployment
documents supersede older plans on those subjects. When operating the application API,
authenticate and read the current permission-filtered `GET /api` handbook; repository-only
coding does not require production sign-in. Language-specific examples in generic skills
apply only to that language; this Rails app does not inherit React/TypeScript conventions.
Inherited memories are dated context, not current branch, deployment, UI, or permission
facts. Verify their claims before acting. Local development databases can contain real
member data; use the test database for automated checks and never infer permission to
reset development data. Simplicity guidance does not waive authorization or audit controls.

- `docs/AGENT_ENVIRONMENT.md` — Astra migration, environment boundaries, and verification.

- `README.md` — overview for operators and repo visitors.
- `docs/PURPOSE.md` — why the app exists.
- `docs/USERS.md` — user and organization context.
- `docs/AMERICAN_LEGION_CONTEXT.md` — Legion structure, Four Pillars, Legion Family, source authority, and AI interpretation rules.
- `docs/CALENDAR_API.md` — private calendar/activity endpoints, field semantics, permission matching, and safe public projection.
- `docs/ENDEAVOR_GOVERNANCE.md` — durable identity and ownership rules for continuing Post work.
- `docs/ROLES.md` — people, Post roles, membership-information access, and delegated-agent authority.
- `docs/MEMBER_SIGN_IN_GUIDE.md` — plain-language email sign-in instructions for Post members.
- `docs/USER_MANAGEMENT_GUIDE.md` — Commander and Adjutant procedures for accounts, officers, and permissions.
- `docs/ARCHITECTURE.md` — architecture and durable decisions.
- `docs/ROADMAP.md` — planned development phases.
- `docs/MEETING_FOUNDATION_AND_MEMBER_ARCHIVE.md` — implemented first-class Meeting and member archive boundary.
- `docs/STANDARD_MEMBER_EXPERIENCE.md` — implemented member dashboard, Meeting actions, Endeavor presentation, directory, and Profile treatment.
- `docs/OFFICER_WORKSPACE_EXPERIENCE.md` — current officer-derived access and scoped officer workspace.
- `docs/COMMANDER_AGENDA_AND_ROLL_CALL.md` — agenda wording, Commander/Adjutant notes-copy boundary, and dated officer roll call.
- `docs/PDF_DOCUMENT_DELIVERY.md` — PDF delivery, authorization, rendering, and verification.
- `docs/MINUTES_LIFECYCLE.md` — governing structured drafting, human authority, acceptance, correction, and immutable-record design for Minutes.
- `docs/MINUTES_APPROVAL_AND_ATTESTATION.md` — implemented immutable approval, different-person attestation, member presentation, and delegated provenance.
- `docs/DEPLOYMENT.md` — deployment/operator notes.
- `docs/superpowers/specs/2026-08-22-officer-agent-operability-design.md` — private JSON + handbook so Grok Bot can operate the app for the signed-in user with that user's current grants.
- `docs/superpowers/specs/2026-08-29-agent-agenda-api-parity-design.md` — agent parity for dated-agenda items, historical business backfill, roll calls, catalog changes, and destructive boundaries.
- `docs/superpowers/specs/2026-08-31-agent-minutes-api-parity-design.md` — agent parity for accounts, transcripts, structured draft minutes, AI review, Jobs, and official-action boundaries.
- `docs/agent-operator-skill.md` — short standing brief to paste into Grok Bot (what, where, auth, then `/api`). Deeper operator detail is the signed-in `GET /api` handbook.
