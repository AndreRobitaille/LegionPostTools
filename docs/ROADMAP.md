# Roadmap

This roadmap records current direction. It is expected to evolve as Post 165 uses the app.

## Completed Foundation

- Rails 8.1 application scaffold.
- PostgreSQL-backed domain model.
- First-run setup wizard.
- American Legion Post preset.
- People, users, positions, permissions, organizations, and meeting bodies.
- Passwordless authentication foundation: magic-link email sign-in working; passkey WebAuthn
  backend endpoints in place (front-end pending — see "Immediate Next" below).
- Minimal authenticated dashboard.
- Visual design system — "The 1919" Art Deco direction with palette, typography, component
  vocabulary, and a readability hard rule (`docs/superpowers/specs/2026-07-11-visual-design-system-design.md`).
- Styled sign-in and magic-link confirmation screens on a dedicated entry layout, using the
  official American Legion emblem and a configurable organization identity (name + locality).

## Current Documentation Foundation

- README for operators and repo visitors.
- Agent instructions.
- Purpose, users, architecture, roadmap, and deployment notes.

## Immediate Next: Complete the Authentication Flow

The full login/passkey/email flow is the current focus, ahead of the next product slice.
Magic-link sign-in and the passkey WebAuthn backend work today; still to build are the passkey
front-end (the login button is a placeholder), a guided "add a passkey" step after first
login, a styled passkey management (Security) page, and dev + production email delivery
(no dev mail viewer, and `Procfile.dev` runs no job worker).

Design, current-state assessment, gaps, open decisions, and definition of done:
`docs/superpowers/specs/2026-07-11-authentication-flow-design.md`.

## Next Product Slice: Structured Agendas

- Meeting templates.
- Agenda sections.
- Structured agenda items.
- Item-level rich notes.
- Reordering and moving agenda items.
- Browser/HTML printable agenda rendering for on-screen review and printing.

## Tracked Items

- Long-lived topics, projects, issues, and institutional history.
- Ability to add tracked items to agendas.
- Old business suggestions from active tracked items.
- Human-confirmed merging or splitting later if AI suggestions are added.

## Minutes Lifecycle

- Transcript paste/upload.
- Draft/review/approval/attestation/acceptance workflow.
- AI-assisted transcript-to-minutes drafting within that workflow.
- Adjutant review.
- Commander approval.
- Adjutant attestation.
- Acceptance by motion at the next same-body meeting.
- Immutable official archive after acceptance.

## Export and Distribution

- PDF generation for finalized records.
- Email distribution of finalized documents.
- Delivery records for sent documents.

## Deployment

- Harden Kamal production deployment.
- Configure production host, WebAuthn, mail, storage, and background jobs.
- Deploy as a separate service on the shared Hetzner VPS.

## Later Possibilities

- Document archive.
- Committee tracking.
- Calendar/events.
- Lightweight finance records.
- Officer/member directory.
- Public read-only API for selected approved records.
