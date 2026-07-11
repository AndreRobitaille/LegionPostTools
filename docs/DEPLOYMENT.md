# Deployment

This document records deployment constraints and operator notes.

## Production Target

Production is expected to run on a Hetzner Cloud VPS.

That server already hosts another Rails application deployed with Kamal. LegionPostTools must be deployed as a separate Kamal service and must not assume it is the only application on the server.

## Naming Rules

Use unique names for:

- Kamal service name.
- Docker image name.
- PostgreSQL database.
- Volumes.
- Accessory containers.
- Networks or other shared infrastructure resources.

Avoid names that could conflict with existing applications on the VPS.

## Current Stack

- Rails 8.1.
- PostgreSQL.
- Docker.
- Kamal.
- Active Storage.
- Solid Queue.

## Required Production Environment

Authentication requires these production values:

- `APP_HOST` — public hostname, for example `legion.tworiversmatters.com`.
- `MAIL_FROM` — sender address for application email.
- `WEBAUTHN_ORIGIN` — full origin, for example `https://legion.tworiversmatters.com`.
- `WEBAUTHN_RP_ID` — relying party ID, usually the hostname.
- `WEBAUTHN_RP_NAME` — display name, usually `LegionPostTools` or the post name.

Rails/Kamal also requires normal production secrets such as `RAILS_MASTER_KEY` and database credentials.

## Email

Email provider integration is not finalized.

Likely options:

- Loops.so if it works well for transactional auth messages and document distribution.
- SMTP or another transactional email provider if Loops.so is not suitable.

Keep email behind a replaceable boundary. Do not scatter provider-specific assumptions through the domain model.

## AI Provider

AI minutes drafting is planned but not implemented yet.

OpenAI is expected first. API keys should come from environment variables or Rails credentials, not ordinary database settings.

## Deployment Checklist Direction

Before production deployment:

- Confirm unique Kamal service/image/database/volume names.
- Configure production host and WebAuthn env vars.
- Configure email delivery.
- Confirm SSL/HTTPS behavior.
- Confirm database backup plan.
- Confirm Active Storage persistence.
- Confirm background jobs run.
- Run `bin/rails test`, `bin/brakeman`, `bin/rubocop`, and `bin/bundler-audit`.
