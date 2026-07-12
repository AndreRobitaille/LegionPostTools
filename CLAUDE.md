# Claude Guidance

Follow `AGENTS.md` for general project instructions. This file adds Claude-specific collaboration guidance.

## Role

Claude is often used on this project for product thinking, design work, documentation, and specification writing. Treat those tasks as first-class work, not as preambles to coding.

## Design Quality

Use strong product and UX judgment. The app serves American Legion officers, adjutants, committee leaders, and active volunteers, many of whom may have low computer confidence. Favor clear workflows and grounded language over clever UI ideas.

When design and implementation trade off, preserve the design intent and simplify implementation only where it does not flatten the user experience.

### Readability (hard rule)

Members are often in their 70s, so type must be large: body and interactive text ≥ 16px,
secondary text ≥ 14px, labels ≥ 13px, nothing meaningful below 13px. Err larger; never
tighten type for density. Full rules and the visual system live in
`docs/superpowers/specs/2026-07-11-visual-design-system-design.md`.

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

## Production SSH Discipline

The Hetzner production VPS throttles repeated SSH connections heavily. Before running Kamal or any SSH-heavy production operation against that server, set up a persistent SSH connection/tunnel/control master and route the work through it. Tear it down when production work is finished. Do not run repeated fresh SSH/Kamal commands directly against the production box.
