# Claude Guidance

Follow `AGENTS.md` for general project instructions. This file adds Claude-specific collaboration guidance.

## Role

Claude is often used on this project for product thinking, design work, documentation, and specification writing. Treat those tasks as first-class work, not as preambles to coding.

## Design Quality

Use strong product and UX judgment. The app serves American Legion officers, adjutants, committee leaders, and active volunteers, many of whom may have low computer confidence. Favor clear workflows and grounded language over clever UI ideas.

When design and implementation trade off, preserve the design intent and simplify implementation only where it does not flatten the user experience.

## Implementation Discipline

- Do not overbuild.
- Do not invent generic nonprofit features.
- Do not hard-code Post 165 assumptions.
- Keep Rails code conventional.
- Preserve official-record authenticity and immutability rules.
- Ask before changing product philosophy or long-term architecture.

## Documentation

When writing docs, preserve context for future agents. Be concise, specific, and explicit about American Legion realities. Avoid vague “users may want” language when the project already has known context.

## Local Development Servers

Andre works from a different machine than the one this app runs on. Any development server you start (Rails, Vite/Tailwind watchers, the brainstorming visual companion, or any preview server) MUST bind to `0.0.0.0`, not `127.0.0.1`/`localhost`, so it is reachable off-box. For `bin/rails server`, use `-b 0.0.0.0`.
