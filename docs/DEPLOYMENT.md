# Deployment

Operator guide for Post 165 and repeat maintainer-hosted installs.

## Production model

LegionPostTools is deployed one app/database set per post or unit. Do not combine multiple posts into one Rails database.

The app is not a SaaS or multi-tenant platform. Each installation gets its own Kamal service, image, databases, and storage.

## First production host

- Hostname: `members.wipost165.org`
- Server: shared Hetzner VPS `178.156.250.235`
- Co-hosted app: `TwoRiversReporter`

Primary deployment flow is from the local repo with `bin/kamal deploy`. Use `bin/kamal setup` for the First install only, when provisioning a new deployment target. Do not use a server-side git clone or web UI as the primary flow.

## Naming convention

Use install-specific names in the form:

`legion_<unit_type>_<unit_number>_<department_abbreviation>_tools_<purpose>`

Example: Post 165 in Wisconsin uses `legion_post_165_wi_tools`.

For department abbreviations, use the American Legion state-level Department abbreviation, such as `wi`.

Post 165 concrete names:

- Service: `legion_post_165_wi_tools`
- Image: `andrerobitaille/legion-post-165-wi-tools`
- Primary DB: `legion_post_165_wi_tools_production`
- Cache DB: `legion_post_165_wi_tools_production_cache`
- Queue DB: `legion_post_165_wi_tools_production_queue`
- Postgres persistent directory: `legion_post_165_wi_tools_pgdata`
- Active Storage volume: `legion_post_165_wi_tools_storage`

## Required environment and secrets

Required Kamal secrets:

- `RAILS_MASTER_KEY`
- `KAMAL_REGISTRY_PASSWORD`
- `LEGION_POST_TOOLS_DATABASE_PASSWORD`
- `LOOPS_API_KEY`
- `LOOPS_MAGIC_LINK_TEMPLATE_ID`

Kamal aliases `LEGION_POST_TOOLS_DATABASE_PASSWORD` to the container's `POSTGRES_PASSWORD`; do not list `POSTGRES_PASSWORD` as a separate required secret.

Required clear env values:

- `APP_HOST`
- `MAIL_PROVIDER=loops` (preferred/default for Post 165)
- `MAIL_FROM`
- `WEBAUTHN_ORIGIN`
- `WEBAUTHN_RP_ID`
- `WEBAUTHN_RP_NAME`
- `DB_HOST`
- `SOLID_QUEUE_IN_PUMA`
- `POSTGRES_DB`
- `POSTGRES_CACHE_DB`
- `POSTGRES_QUEUE_DB`

If an install is not using Loops, `MAIL_PROVIDER=action_mailer` is the SMTP/Action Mailer alternative. Configure the usual SMTP delivery settings for that install.

For Post 165, `DB_HOST` should point at the Kamal Postgres accessory hostname on the Docker network.

## Persistent SSH control master

Before any Kamal or SSH-heavy operation, establish a persistent SSH control master. Route the deployment work through that connection and tear it down afterward.

Do not run repeated fresh SSH/Kamal commands directly against the Hetzner host.

## Postgres accessory

The Postgres accessory uses `config/postgres/init.sh`, not `init.sql`, to create the cache and queue databases from environment variables.

The database data is persisted through the Kamal accessory `directories:` entry:

`legion_post_165_wi_tools_pgdata:/var/lib/postgresql/data`

Treat this as the accessory's persistent directory. Active Storage uses the Docker volume `legion_post_165_wi_tools_storage`.

## Email and WebAuthn

- `MAIL_PROVIDER=loops` uses the Loops transactional API and is the preferred/default Post 165 path.
- Set `LOOPS_API_KEY` and `LOOPS_MAGIC_LINK_TEMPLATE_ID` when using Loops.
- `MAIL_PROVIDER=action_mailer` uses Action Mailer/SMTP for production email.
- `WEBAUTHN_ORIGIN` must be the HTTPS origin, such as `https://members.wipost165.org`.
- `WEBAUTHN_RP_ID` must be the exact host for this deployment, such as `members.wipost165.org`, without scheme or port. Future operators may choose a parent registrable domain only if they deliberately want credentials to work across subdomains.
- `WEBAUTHN_RP_NAME` should be the post or app display name.

Passkeys require HTTPS and do not work by IP address.

## First deploy checklist: Post 165

1. Confirm DNS for `members.wipost165.org` points at `178.156.250.235`.
2. Establish the persistent SSH control master.
3. Set all required Kamal secrets.
4. Set clear env values, especially `APP_HOST`, `WEBAUTHN_ORIGIN`, `WEBAUTHN_RP_ID`, `DB_HOST`, and the canonical DB names.
5. Confirm the Kamal service name, image name, and storage names match the Post 165 convention.
6. Run `bin/kamal setup` from the local repo for the First install only.
7. Run `bin/kamal deploy` from the local repo.
8. Verify the app, sign-in email, passkeys, and persistence.
9. Tear down the SSH control master.

## Repeat hosted install checklist

1. Choose a unique install-specific service, image, database, and volume set.
2. Follow the naming convention above.
3. Keep the one-app-one-database-set rule.
4. Set host, email, WebAuthn, and database env values for the new install.
5. Use the same local `bin/kamal setup` and `bin/kamal deploy` flow, with `setup` reserved for First install only.
6. Keep storage and database backups scoped to that install only.

## Backups and restore expectations

- Back up the Postgres accessory data and the Active Storage volume separately.
- Preserve the install-specific database names for restores.
- Rehearse restores before depending on them in production; record a restore rehearsal for each install.
- A restore should bring back the primary database first, then cache/queue if needed, then Active Storage files.
- Do not assume another post's backup can be mixed into this install.

## Verification commands

Run the usual app checks before production deploys:

```bash
bin/rails test
bin/brakeman
bin/rubocop
bin/bundler-audit
```

For deployment-specific checks, also confirm:

- Only run `bin/kamal setup` for initial provisioning or a new install.
- `bin/kamal deploy` for routine production deploy verification.
- a real sign-in email reaches inbox
- a passkey sign-in works at `APP_HOST`
- storage survives a container restart
- restore rehearsal evidence exists for the install
