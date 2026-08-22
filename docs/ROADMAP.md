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

Completed for the first production setup:

- Configured `members.wipost165.org` on the shared Hetzner VPS as a separate Kamal service.
- Used install-specific names such as `legion_post_165_wi_tools` for service, databases, and volumes.
- Provisioned a dedicated PostgreSQL accessory and Active Storage volume for this install.
- Followed persistent SSH control-master discipline before Kamal and SSH-heavy production work, then tore the connection down afterward.
- Completed first-run setup for Robert E. Burns Post 165.
- Verified HTTPS app availability, health check, production magic-link delivery, production magic-link sign-in, and administrator dashboard access on the real hostname.
- Verified production passkey registration and passkey sign-in.
- Verified roster import and admin access-control workflows.
- Verified that `request.remote_ip` resolves to the real client IP behind the Kamal proxy.
- Confirmed the co-hosted TwoRiversReporter app still responded after deployment.
- Backup and restore are handled as server-side operations outside the application roadmap.
- Updated deployment documentation so the same pattern can later be repeated for another hosted American Legion post or unit without creating a SaaS/multi-tenant app.

Still pending before inviting broader member use:

- Verify storage persistence across a container restart after file-upload workflows exist.

## Completed: Structured Agendas Foundation

With authentication and roster-backed administration in place, build the meeting record core.

Completed for Structured Agendas foundation:

- Organization-owned agenda item catalog with editable local copies.
- Lean regular-meeting baseline seeded from The American Legion Officer's Guide and Manual of Ceremonies.
- Admin management for catalog categories, behavior types, active status, and rich text/script bodies.
- Meeting type templates: seeded PEC Meeting and Membership Meeting, admin-created meeting types, catalog-item picker, template-specific rich text wording overrides, and item ordering/removal.
- Dated agendas: officer-created agendas for actual meeting dates, copied from meeting type templates, editable before approval/publication, with member read-only and printable HTML views.
- Structured agenda sections: reusable section chapters in meeting type templates, copied independently into dated agendas, with guided item placement, accessible ordering controls, and section-aware member/print views.

Still pending:

- Later guided workflow to create a new catalog item from the meeting type/template editor and add it directly to that template.

## Completed: Tracked Items Foundation

- Long-lived post business with rich context, importance, raise-by dates, usual meeting
  bodies, and active/completed lifecycle.
- Append-only dated updates and a continuity record that includes agenda appearances.
- Plain-language old-business priority suggestions from active tracked items.
- Independent tracked-item snapshots added to chosen sections of draft agendas.
- Read access for signed-in members and management through `manage_agendas`.

Still pending:

- Human-confirmed merging or splitting if AI suggestions are added later.

## Completed: Agenda Presentation and Navigation

Completed before beginning the minutes lifecycle:

- Polished member-facing meeting docket and published-agenda document.
- Responsive and print presentation suitable for reading at a meeting or distributing
  as a printed handout.
- Primary navigation links only to working features, including member Meetings access.
- Active-state, permission, keyboard, desktop, and phone-width verification.
- See `docs/AGENDA_PRESENTATION.md`.

## Current: Officer Agent Operability

Let Grok Bot (and later a similar machine-resident agent) operate the app as a
signed-in Post Commander so repetitive officer work can be handed off. The Bot
does the thinking. The app stays a predictable operations tool. This track uses
agendas and tracked items that already exist; it does not wait for minutes.

Immediate jobs this phase must unlock:

- Explicit orders such as “create a basic PEC agenda for next Tuesday” and
  “add the car show topic to the next meeting agenda.”
- Morning group-chat triage **in Grok Bot**, which then creates or updates
  tracked business and draft agenda entries here. Chat never enters this app.

Build:

- Private session-authenticated JSON for meeting bodies, meeting types, dated
  agendas, and tracked items. Same `can?` rules as the HTML app.
- Generated handbook at `GET /api` (login required) so the Bot can learn this
  installation without a human manual, MCP, or public docs. Standing
  instructions to paste into the Bot live in `docs/agent-operator-skill.md`
  (what the app is, URL, sign-in, then `/api`). Job routines stay in the Bot.
- Lists, not search. The Bot matches names from the list.
- Draft-only creates unless the human explicitly asks to approve or publish.
- Verify the Agent Computer browser can sign in and reach `/api` (watch
  `allow_browser`).

Do not build in this phase: TUI, CLI package, MCP, API tokens, public
`llms.txt`, chat ingest, or minutes endpoints.

See `docs/superpowers/specs/2026-08-22-officer-agent-operability-design.md` and
`docs/superpowers/plans/2026-08-22-officer-agent-operability.md`.

When minutes, PDF, or distribution ship, add them to the handbook. A personal
access token waits until a shell-only agent cannot use the 180-day session
cookie. MCP waits until a host with no shell needs the same actions.

## Immediate Next: Minutes Lifecycle

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
- Public read-only API for selected approved records (distinct from the private
  officer-agent API).
- Personal access tokens or MCP wrapping that private API, if a future agent
  cannot use the session-authenticated handbook.
