# Deployment

This document records deployment constraints and operator notes.

## Production Target

Production is expected to run on a Hetzner Cloud VPS.

That server already hosts another Rails application deployed with Kamal. LegionPostTools must be deployed as a separate Kamal service and must not assume it is the only application on the server.

## Naming Rules

Use unique names for:

- Kamal service name.
- Docker image name.
- PostgreSQL databases: primary, cache, and queue.
- Volumes.
- Accessory containers.
- Networks or other shared infrastructure resources.

Avoid names that could conflict with existing applications on the VPS.

Production uses three PostgreSQL databases: primary, cache, and queue. All three must have unique, non-conflicting names on the shared host.

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
- `MAIL_PROVIDER` — `loops` (preferred) or `action_mailer` (SMTP). See the Email section.
- `MAIL_FROM` — sender address (used by the Action Mailer backend).
- `LOOPS_API_KEY` / `LOOPS_MAGIC_LINK_TEMPLATE_ID` — required when `MAIL_PROVIDER=loops`.
- `WEBAUTHN_ORIGIN` — full origin, for example `https://legion.tworiversmatters.com`.
- `WEBAUTHN_RP_ID` — relying party ID: the registrable domain, no scheme or port (e.g.
  `legion.tworiversmatters.com`). A mismatch with the browser origin makes passkeys fail silently.
- `WEBAUTHN_RP_NAME` — display name, usually `LegionPostTools` or the post name.

Passkeys require a secure context (HTTPS). They do not work over plain HTTP or when the app is
reached by IP address, so passkey sign-in only functions once TLS is terminated for `APP_HOST`.

Rails/Kamal also requires normal production secrets such as `RAILS_MASTER_KEY` and database credentials.

Current production expects `LEGION_POST_TOOLS_DATABASE_PASSWORD` for database access unless you are deliberately documenting a future URL-based alternative.

## Email

Email delivery is behind a replaceable boundary: the `MailDelivery` seam
(`app/services/mail_delivery.rb`). Callers use `MailDelivery.deliver_magic_link(user:, login_url:)`;
the backend is chosen at boot by `MAIL_PROVIDER` (see `config/initializers/mail_delivery.rb`).

| `MAIL_PROVIDER` | Backend | Notes |
|-----------------|---------|-------|
| `action_mailer` (default) | `MailDelivery::ActionMailerBackend` | Normal Action Mailer pipeline; configure SMTP in `config/environments/production.rb` and set `MAIL_FROM`. Renders the branded ERB template. |
| `loops` | `MailDelivery::LoopsBackend` | Posts to the Loops.so transactional API. The email body is rendered by a **Loops template**, not the ERB template. |

For **Loops.so** (`MAIL_PROVIDER=loops`), also set:

- `LOOPS_API_KEY` — Loops transactional API key.
- `LOOPS_MAGIC_LINK_TEMPLATE_ID` — id of the Loops transactional template for the sign-in email.
  Create a transactional template in the Loops dashboard that references `{{login_url}}` and
  `{{name}}`, then set this to its id.

**Validate deliverability first:** whichever provider, send yourself a real sign-in link on the
host and confirm inbox placement (SPF/DKIM/DMARC aligned) before onboarding members. This is an
operator step; it is not covered by automated tests.

Do not scatter provider-specific assumptions through the domain model — add a new backend under
`app/services/mail_delivery/` rather than branching in callers.

## AI Provider

AI minutes drafting is planned but not implemented yet.

OpenAI is expected first. API keys should come from environment variables or Rails credentials, not ordinary database settings.

## Deployment Checklist Direction

`config/deploy.yml` is currently a scaffold/default and must be completed before any production deploy. The real host, registry, proxy/routing, SSL, and shared-host settings are not finalized yet.

Uploads currently use local-disk Active Storage on a mounted Kamal volume, so that volume must be backed up and preserved. Background jobs currently use Solid Queue and run in-process with the web container for the single-server deployment.

Before production deployment:

- Confirm unique Kamal service/image/primary-cache-queue database/volume names.
- Configure production host and WebAuthn env vars.
- Configure email delivery.
- Confirm SSL/HTTPS behavior.
- Confirm primary/cache/queue database backup plan.
- Confirm Active Storage persistence.
- Confirm background jobs run.
- Run `bin/rails test`, `bin/brakeman`, `bin/rubocop`, and `bin/bundler-audit`.
