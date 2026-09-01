# Agent Instructions

Read this file before making code or documentation changes.

## Project Identity

LegionPostTools is American Legion software. It is specifically for American Legion posts and, where useful, the American Legion Family. Do not reframe it as generic nonprofit software.

The first real installation is Robert E. Burns Post 165 in Two Rivers, Wisconsin. Use Post 165 as grounding context, but do not hard-code Post 165 names, numbers, locations, officer rosters, URLs, or assumptions into application behavior.

## Core Product Principles

- Meeting records are the first-class workflow.
- Authenticity matters more than convenience once records become official.
- Accepted official minutes are immutable. Later corrections must be later amendments or later meeting records, not edits to accepted minutes.
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
- Active Storage.
- Solid Queue.
- Docker and Kamal for deployment.
- Passwordless authentication with passkeys and magic links.

## Design Before Implementation

Every feature requires deliberate product and UX design work appropriate to its scope. For meaningful product changes, write or update a design/spec before implementation. This is especially important for meeting workflows, official records, AI drafting, permissions, deployment, or user-facing flows.

Do not jump directly from idea to code when the change affects product behavior or long-term architecture.

For every feature that adds or changes user-facing UI, invoke an available frontend or visual design skill while planning and implementing it. Record the intended visual direction before coding, follow the established visual system, and critique the rendered result at desktop and narrow widths before calling the feature complete. Design is part of implementation, not optional polish after the feature works.

## Local Development Servers

The developer typically works from a different machine than the one running the app. Bind any development server to `0.0.0.0` (not `127.0.0.1`/`localhost`) so it is reachable off-box. For `bin/rails server`, use `-b 0.0.0.0`. This applies to Tailwind/asset watchers, preview servers, and any tooling that serves over HTTP.

## Verification

Before claiming work is complete, run relevant checks and report exact results.

Common checks:

```bash
bin/rails test
bin/brakeman
bin/rubocop
bin/bundler-audit
```

For browser-visible flows, also run a browser smoke test when practical.

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

- `README.md` — overview for operators and repo visitors.
- `docs/PURPOSE.md` — why the app exists.
- `docs/USERS.md` — user and organization context.
- `docs/AMERICAN_LEGION_CONTEXT.md` — Legion structure, Four Pillars, Legion Family, source authority, and AI interpretation rules.
- `docs/ENDEAVOR_GOVERNANCE.md` — durable identity and ownership rules for continuing Post work.
- `docs/ROLES.md` — people, Post roles, membership-information access, and delegated-agent authority.
- `docs/MEMBER_SIGN_IN_GUIDE.md` — plain-language email sign-in instructions for Post members.
- `docs/USER_MANAGEMENT_GUIDE.md` — Commander and Adjutant procedures for accounts, officers, and permissions.
- `docs/ARCHITECTURE.md` — architecture and durable decisions.
- `docs/ROADMAP.md` — planned development phases.
- `docs/MEETING_FOUNDATION_AND_MEMBER_ARCHIVE.md` — implemented first-class Meeting and member archive boundary.
- `docs/MINUTES_LIFECYCLE.md` — governing structured drafting, human authority, acceptance, correction, and immutable-record design for Minutes.
- `docs/DEPLOYMENT.md` — deployment/operator notes.
- `docs/superpowers/specs/2026-08-22-officer-agent-operability-design.md` — private JSON + handbook so Grok Bot can operate the app for the signed-in user with that user's current grants.
- `docs/superpowers/specs/2026-08-29-agent-agenda-api-parity-design.md` — agent parity for dated-agenda items, historical business backfill, roll calls, catalog changes, and destructive boundaries.
- `docs/superpowers/specs/2026-08-31-agent-minutes-api-parity-design.md` — agent parity for accounts, transcripts, structured draft minutes, AI review, Jobs, and official-action boundaries.
- `docs/agent-operator-skill.md` — short standing brief to paste into Grok Bot (what, where, auth, then `/api`). Deeper operator detail is the signed-in `GET /api` handbook.
