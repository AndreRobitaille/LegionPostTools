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
- Roster-backed administration: admin section, National roster CSV import keyed by Member ID,
  dated read-only roster fields with 30-day freshness warnings, people/member list and detail
  views, person-to-user login management, app permission assignment, post role assignment with
  effective dates, and roster/login email mismatch review. See
  `docs/superpowers/specs/2026-07-11-admin-and-roster-import-design.md`.

## Current Documentation Foundation

- README for operators and repo visitors.
- Agent instructions.
- Purpose, users, architecture, roadmap, and deployment notes.

## Production Readiness Side-Roadmap

As a bounded operational track, prepare the first real production installation for Robert E. Burns Post 165. This does not replace Structured Agendas as the next core product workflow.

- Configure `members.wipost165.org` on the shared Hetzner VPS as a separate Kamal service.
- Use install-specific names such as `legion_post_165_wi_tools` for service, databases, and volumes.
- Use a dedicated PostgreSQL accessory and Active Storage volume for this install.
- Follow persistent SSH control-master discipline before any Kamal or SSH-heavy production work.
- Rehearse production on the real hostname before inviting members.
- Verify HTTPS, WebAuthn/passkeys, magic links, roster import, admin access control, backups, restore, and storage persistence.
- Update deployment documentation so the same pattern can later be repeated for another hosted American Legion post or unit without creating a SaaS/multi-tenant app.

## Immediate Next: Structured Agendas

With authentication and roster-backed administration in place, build the meeting record core.

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

- Longer-term deployment hardening beyond the Production Readiness Side-Roadmap.
- Harden Kamal production deployment for repeatable future installs.
- Expand deployment automation and operational checks for additional American Legion posts or units.
- After deploying behind the Kamal proxy, verify that `request.remote_ip` resolves to real
  client IPs (not the proxy). The auth rate limits key on it; if it resolves to the proxy, all
  clients share one throttle bucket and sign-in could be throttled globally. Configure
  `trusted_proxies` if needed.

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
