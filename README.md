# LegionPostTools

LegionPostTools is an internal operations application for American Legion posts and, where useful, the American Legion Family. The first real installation is for Robert E. Burns Post 165 in Two Rivers, Wisconsin.

The app is designed to help officers and active volunteers manage post work with better continuity: people, positions, meeting bodies, agendas, minutes, official records, and eventually AI-assisted minutes drafting.

This is not generic nonprofit software. It is built around American Legion post operations, ceremony, officer turnover, Robert's Rules style meetings, and the need for authentic official records.

## Current Status

The current application foundation includes:

- Rails application scaffold.
- First-run setup wizard.
- American Legion Post setup preset.
- People, users, historical position assignments, permissions, organizations, and meeting bodies.
- Passwordless authentication (complete): magic-link email sign-in and passkey registration
  and sign-in, with a first-login "add a passkey" prompt and a Profile page to
  name, rename, and remove passkeys.
- Compact authenticated app shell and a minimal authenticated dashboard.
- Structured agenda catalog, meeting templates, dated agendas, and reusable agenda sections.
- Endeavors for continuing Post work, with dated continuity updates, meeting-priority suggestions, and
  independent agenda snapshots.
- Polished member agenda navigation, upcoming-meeting docket, and responsive/printable
  published agendas.

Minutes drafting and the human review/approval/attestation/acceptance lifecycle are next,
followed by PDF/export and email distribution.

## Who This Is For

LegionPostTools is intended for American Legion officers, adjutants, committee leaders, active volunteers, and technically capable members helping operate a post installation.

The first use case is Post 165, a medium-sized post with about 121 members in good standing, 20-25 typical meeting attendees, and around 15 fairly active volunteers/officers/committee participants.

Most ordinary post members are not expected to log in during early versions. They may receive agendas, minutes, or records produced by the app.

## Documentation

- `AGENTS.md` and `CLAUDE.md` — general agent instructions and Claude-specific collaboration guidance.
- `docs/PURPOSE.md` — why the app exists.
- `docs/USERS.md` — user and organization context.
- `docs/AMERICAN_LEGION_CONTEXT.md` — Legion structure, source authority, Four Pillars, and Legion Family boundaries.
- `docs/ENDEAVOR_GOVERNANCE.md` — durable identity and ownership rules for continuing Post work.
- `docs/ENDEAVOR_DEVELOPMENT_PLAN.md` — completed Endeavor foundation, minutes integration, and deferred work.
- `docs/MEETING_FOUNDATION_AND_MEMBER_ARCHIVE.md` — the first-class Meeting and archive milestone before minutes.
- `docs/ROLES.md` — people, Post roles, membership-information access, and delegated-agent authority.
- `docs/ARCHITECTURE.md` — architecture and durable product decisions.
- `docs/ROADMAP.md` — planned development phases.
- `docs/DEPLOYMENT.md` — deployment and operator notes.

## Development

Prerequisites:

- Ruby 4.0.0, or the version in `.ruby-version`.
- PostgreSQL available locally for Rails development and test databases.
- libvips for Active Storage image processing. On Omarchy/Arch, install it with `omarchy pkg add libvips`.

```bash
bundle install
bin/rails db:prepare
bin/dev
```

Open `http://localhost:3000`. On a fresh database, the app shows the first-run setup wizard.

## Authentication

LegionPostTools is passwordless. Users sign in with passkeys or a login email that
contains both a one-click link and a browser-bound eight-digit code. Passwords are
intentionally not supported.

Signed-in users may create named, expiring personal agent tokens under
**Profile → Agent access**. The app shows each token once, stores only its digest,
and applies the user's current grants on every API request.

Required production auth environment variables:

- `APP_HOST`
- `MAIL_FROM`
- `WEBAUTHN_ORIGIN`
- `WEBAUTHN_RP_ID`
- `WEBAUTHN_RP_NAME`

## Verification

Run the main checks before claiming work is complete:

```bash
bin/rails test
bin/brakeman
bin/rubocop
bin/bundler-audit
```

## Smoke Test

For a fresh local setup:

```bash
bin/rails db:drop db:create db:migrate
bin/rails server -b 0.0.0.0 -p 3000
```

Open `http://localhost:3000`, complete the setup wizard, then verify the setup counts:

```bash
bin/rails runner 'puts [Installation.count, Organization.count, PositionTitle.count, MeetingBody.count, User.count].join(" ")'
```

Expected after first setup:

```text
1 1 11 2 1
```
