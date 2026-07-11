# Documentation Foundation Design

## Summary

LegionPostTools needs a documentation foundation before the next feature slice. The documentation should preserve product memory, project philosophy, user context, architectural decisions, and development constraints so future contributors and AI coding agents can make good decisions without repeatedly rediscovering the same context.

This is not an end-user manual yet. The primary audience is developers, contributors, maintainers, and AI/LLM agents working on the codebase.

## Audience

The documentation should serve:

- Developers and contributors building the application.
- AI coding agents that need concise, durable project context.
- Future maintainers deploying or operating the software.
- Technically capable Legion volunteers helping install or support the app.

The documentation is not primarily for ordinary post members or nontechnical end users.

## Product Identity

The docs must be explicit that LegionPostTools is American Legion software.

- It is specifically for American Legion posts and, where useful, the American Legion Family.
- It is not generic nonprofit management software.
- The first real installation is Robert E. Burns Post 165 in Two Rivers, Wisconsin.
- Post 165 should ground the product context, but the application should not hard-code Post 165 assumptions.
- The app should remain configurable so another post or Legion-family installation can run it later.

## User Context to Preserve

The docs should describe the real-world context that shapes product decisions:

- Post 165 is a medium-sized post, not a tiny test organization.
- It has about 121 members in good standing.
- About 20-25 members attend typical meetings.
- About 15 people are fairly active in officer, committee, or volunteer work.
- Many likely users are older and may have low computer confidence.
- Initial active users are likely the Commander and Adjutant, with officers and committee leaders/members added over time.
- Most members may receive agendas, minutes, or records without logging into the app.

## Documentation Structure

Use a small number of easy-to-remember files so humans and agents are likely to read them.

```text
README.md
AGENTS.md
CLAUDE.md

docs/
  PURPOSE.md
  USERS.md
  ARCHITECTURE.md
  ROADMAP.md
  DEPLOYMENT.md
```

Do not create a large nested documentation hierarchy for this pass. Avoid file names that are hard to remember or easy to ignore.

## File Responsibilities

### README.md

The README is for someone evaluating, installing, or running the software.

It should cover:

- What LegionPostTools is.
- Who it is for.
- Current maturity/status.
- Basic development setup.
- Passwordless authentication overview.
- Required production auth environment variables.
- Links to the deeper docs.

The README should not read like generic open-source marketing, and it should not be only a Rails developer checklist.

### AGENTS.md

`AGENTS.md` is the primary instruction file for coding agents and contributors.

It should cover:

- Read this file first.
- This is American Legion software, not generic nonprofit software.
- Favor Rails conventions, boring code, and maintainability.
- Keep the app configurable and avoid hard-coded Post 165 assumptions.
- Design before implementation for meaningful product changes.
- Treat official records and accepted minutes as immutable.
- Use tests and static checks before claiming completion.
- Preserve deployment constraints: Kamal, PostgreSQL, Docker, shared Hetzner VPS, unique service/database/volume names.
- Use the deeper docs for product context.

### CLAUDE.md

`CLAUDE.md` is Claude-specific guidance, but it may be read outside Claude Code through other harnesses.

It should:

- Point to `AGENTS.md` as the general project instruction source.
- Note that Claude is often used for design, product, documentation, and specification work.
- Emphasize strong product judgment, design quality, and user-context awareness.
- Warn against overbuilding implementation.
- Encourage concise documentation that preserves context for future agents.

### docs/PURPOSE.md

`PURPOSE.md` explains why the app exists.

It should cover:

- American Legion post operations.
- The importance of records, continuity, officer turnover, and institutional memory.
- Respect for ceremony, Robert's Rules, official minutes, and post governance.
- The app's role as an assistant to officers and adjutants, not a replacement for them.
- AI drafts and organizes; humans decide, approve, attest, and accept.

### docs/USERS.md

`USERS.md` captures the people the app serves and the assumptions developers should remember.

It should cover:

- Commander.
- Adjutant.
- Officers.
- Committee chairs and committee members.
- Active volunteers.
- General post members as recipients or subjects of records, not necessarily app users.
- Age, accessibility, and low-computer-confidence realities.
- Post 165's current size and meeting participation as grounding context.

### docs/ARCHITECTURE.md

`ARCHITECTURE.md` should combine technical architecture and durable product decisions.

It should cover:

- Rails, PostgreSQL, Hotwire/Turbo, Tailwind, Action Text, Active Storage, Solid Queue, Docker, Kamal.
- Single installation, configurable organization/unit model.
- Future room for Legion Family units without modeling every legal relationship now.
- People, users, historical position assignments, and permission grants.
- Passwordless auth: passkeys first, magic-link fallback, no passwords.
- Meeting bodies as recurring groups such as PEC and Membership.
- Accepted official minutes are immutable; corrections happen through later amendments.
- Structured agenda items are preferred over raw freeform documents.
- Rich text belongs inside structured records, not as the whole structure.
- AI provider integration should stay behind replaceable service boundaries.
- Public API, SaaS/multi-tenancy, full finance, and broad project management are deferred.

### docs/ROADMAP.md

`ROADMAP.md` describes known development phases without pretending all details are fixed.

It should cover:

- Completed foundation: Rails app, setup wizard, passwordless auth, people/org/role model.
- Documentation foundation.
- Structured agenda templates, sections, and agenda items.
- Tracked items for long-lived topics/projects/history.
- Meeting minutes lifecycle: draft, Adjutant review, Commander approval, Adjutant attestation, distribution, acceptance, immutable archive.
- AI-assisted transcript-to-minutes drafting.
- Export/PDF/email distribution.
- Deployment hardening.
- Later document archive, committees, lightweight finance, calendar/events, and possible API.

### docs/DEPLOYMENT.md

`DEPLOYMENT.md` is for operators and future deployment work.

It should cover:

- Production target: Hetzner Cloud VPS.
- The VPS already hosts another Rails/Kamal app.
- LegionPostTools must use unique Kamal service names, Docker image names, databases, volumes, and related resources.
- PostgreSQL, Docker, Kamal, Active Storage, background jobs.
- Required production env vars for app host, mail from, WebAuthn origin/RP settings.
- Email provider remains to be finalized, likely Loops.so or another transactional provider.
- OpenAI/API provider credentials will be needed later for AI minutes drafting.
- Deployment checklist should stay conservative and explicit.

## Tone and Style

- Clear, direct, and specific.
- Avoid generic nonprofit language.
- Avoid marketing fluff.
- Avoid overpromising current maturity.
- Prefer stable project doctrine over long prose.
- Make docs useful as LLM context.
- Keep files concise enough that agents can read them in full.

## Scope of This Documentation Pass

This pass should create or update documentation only. It should not add application features.

Included:

- Expand `README.md`.
- Add `AGENTS.md`.
- Add `CLAUDE.md`.
- Add `docs/PURPOSE.md`.
- Add `docs/USERS.md`.
- Add `docs/ARCHITECTURE.md`.
- Add `docs/ROADMAP.md`.
- Add `docs/DEPLOYMENT.md`.

Out of scope:

- End-user manual.
- Screenshots or visual walkthroughs.
- Deployment implementation.
- Agenda/minutes feature implementation.
- Large nested docs hierarchy.

## Validation

The documentation implementation should be checked by:

- Reading each file for clarity, consistency, and duplication.
- Verifying README links point to existing files.
- Running the Rails test suite to ensure documentation-only changes did not disturb the app.
- Checking git status so user-owned reference documents are not accidentally committed unless explicitly requested.
