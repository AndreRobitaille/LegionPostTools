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

For meaningful product changes, write or update a design/spec before implementation. This is especially important for meeting workflows, official records, AI drafting, permissions, deployment, or user-facing flows.

Do not jump directly from idea to code when the change affects product behavior or long-term architecture.

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

## Documentation Map

- `README.md` — overview for operators and repo visitors.
- `docs/PURPOSE.md` — why the app exists.
- `docs/USERS.md` — user and organization context.
- `docs/ARCHITECTURE.md` — architecture and durable decisions.
- `docs/ROADMAP.md` — planned development phases.
- `docs/DEPLOYMENT.md` — deployment/operator notes.
