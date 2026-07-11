# Roadmap

This roadmap records current direction. It is expected to evolve as Post 165 uses the app.

## Completed Foundation

- Rails 8.1 application scaffold.
- PostgreSQL-backed domain model.
- First-run setup wizard.
- American Legion Post preset.
- People, users, positions, permissions, organizations, and meeting bodies.
- Passwordless authentication (complete, end-to-end): magic-link email sign-in; passkey
  WebAuthn **registration and sign-in** wired in the browser (feature-detected, with graceful
  fallback to the email link); a first-login "add a passkey" invitation card; and a
  Settings › Security page to name, rename, and remove passkeys. Dev email is viewable via
  `letter_opener_web`; production email runs behind a replaceable delivery boundary (Loops.so).
  See `docs/superpowers/specs/2026-07-11-authentication-flow-design.md`.
- Compact authenticated app shell (header) + minimal authenticated dashboard.
- Visual design system — "The 1919" Art Deco direction with palette, typography, component
  vocabulary, and a readability hard rule (`docs/superpowers/specs/2026-07-11-visual-design-system-design.md`).
- Styled sign-in and magic-link confirmation screens on a dedicated entry layout, using the
  official American Legion emblem and a configurable organization identity (name + locality).

## Current Documentation Foundation

- README for operators and repo visitors.
- Agent instructions.
- Purpose, users, architecture, roadmap, and deployment notes.

## Immediate Next: Structured Agendas

The authentication flow is complete (see Completed Foundation). The next product slice builds
the meeting record core.

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

## Security and Account Continuity

- Full session/device management system: list signed-in browsers/devices in Settings ›
  Security, show last seen/browser/IP context, revoke one session, sign out all other
  sessions, clean up sessions after 180 days of inactivity, revoke sessions on risk
  events, and later support step-up authentication for sensitive actions.

## Later Possibilities

- Document archive.
- Committee tracking.
- Calendar/events.
- Lightweight finance records.
- Officer/member directory.
- Public read-only API for selected approved records.
