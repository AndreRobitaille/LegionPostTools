# Deployment

Operator guide for Post 165 and repeat maintainer-hosted installs.

## Production model

LegionPostTools is deployed one app/database set per post or unit. Do not combine multiple posts into one Rails database.

The app is not a SaaS or multi-tenant platform. Each installation gets its own Kamal service, image, databases, and storage.

## First production host

- Hostname: `members.wipost165.org`
- Server: shared Hetzner VPS `178.156.250.235`
- Co-hosted app: `TwoRiversReporter`
- First production setup: completed for Robert E. Burns Post 165 on July 12, 2026.

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
- `KAMAL_REGISTRY_PASSWORD` (from the local `gh auth token` command in `.kamal/secrets`, or another authenticated `gh` CLI session/token with GHCR access if you change that sourcing)
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

Production SSH credentials are not stored in Kamal secrets. Do not put SSH private keys, SSH certificates, or 1Password SSH references in `.kamal/secrets`.

Use a normal private key file from `~/.ssh/...`. Do not invent certificate-based auth unless `~/.ssh/config` intentionally includes `CertificateFile`.

Kamal must use the same host token as `~/.ssh/config`; for Post 165 that means `Host 178.156.250.235`.

Required SSH stanza, in substance:

```ssh-config
Host 178.156.250.235
  HostName 178.156.250.235
  User root
  IdentityFile ~/.ssh/PRIVATE_KEY_NAME
  IdentityAgent none
  IdentitiesOnly yes
  ControlMaster auto
  ControlPersist 30m
  ControlPath ~/.ssh/controlmasters/legion-post-tools-prod-post-165
```

Create the shared controlmasters directory before use:

```bash
mkdir -p ~/.ssh/controlmasters
chmod 700 ~/.ssh/controlmasters
```

`IdentityAgent none` intentionally disables the 1Password SSH agent for this host.

Practical control-connection commands:

```bash
ssh -MNf 178.156.250.235
ssh -O check 178.156.250.235
ssh -O exit 178.156.250.235
```

Use the shown `ControlPath` only for Post 165; repeat installs must use a unique ControlPath per host/install.

Before any Kamal or SSH-heavy operation, establish a persistent SSH control master. Route the deployment work through that connection and tear it down afterward.

Do not run repeated fresh SSH or Kamal commands directly against the Hetzner host without connection sharing.

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
2. Verify `~/.ssh/config` contains the exact Post 165 host token and control-master stanza.
3. Create `~/.ssh/controlmasters` with `mkdir -p ~/.ssh/controlmasters` and `chmod 700 ~/.ssh/controlmasters`.
4. Start the persistent SSH control master with `ssh -MNf 178.156.250.235`.
5. Set all required Kamal secrets.
6. Set clear env values, especially `APP_HOST`, `WEBAUTHN_ORIGIN`, `WEBAUTHN_RP_ID`, `DB_HOST`, and the canonical DB names.
7. Confirm the Kamal service name, image name, and storage names match the Post 165 convention.
8. Run `ssh -o BatchMode=yes 178.156.250.235 'hostname && docker --version'` once as a preflight check.
9. Run the same `ssh -o BatchMode=yes 178.156.250.235 'hostname && docker --version'` command a second time; it should reuse the shared control connection.
10. Run `bin/kamal setup` from the local repo for the First install only.
11. Run `bin/kamal deploy` from the local repo.
12. Verify the app, sign-in email, passkeys, and persistence.
13. Tear down the SSH control master.

## Post 165 production acceptance record

The first real Post 165 production setup was completed on `members.wipost165.org` with the following acceptance evidence:

- `bin/kamal setup` completed successfully for the initial install.
- `https://members.wipost165.org/up` returned HTTP `200`.
- `https://members.wipost165.org/` loaded the production app.
- The shared Hetzner host still served the existing `TwoRiversReporter` app at `https://tworiversmatters.com/` after setup.
- Running containers included the Post 165 web container, the Post 165 Postgres accessory, the existing TwoRiversReporter containers, and `kamal-proxy`.
- The Post 165 Postgres accessory contained the expected databases:
  - `legion_post_165_wi_tools_production`
  - `legion_post_165_wi_tools_production_cache`
  - `legion_post_165_wi_tools_production_queue`
- The first-run setup wizard was completed with:
  - Organization: `Robert E. Burns Post 165`
  - Unit number: `165`
  - City/state: `Two Rivers, WI`
  - Default meeting location: `Manitowoc Rifle & Pistol Club`, `7227 Sandy Hill Ln, Two Rivers, WI 54241`
  - Initial administrator email: `andre@xyzmodem.com`
- The authenticated dashboard loaded after setup and showed the Post 165 identity, primary navigation, admin access, and the passkey invitation card.
- Sign-out worked from the production dashboard.
- A production magic-link email was delivered to `andre@xyzmodem.com` through Loops.
- Opening the magic-link confirmation screen and choosing **Finish signing in** returned to the authenticated production dashboard.
- Passkey registration and passkey sign-in worked on the real production hostname with the administrator's browser/device.
- Roster import and admin access-control workflows worked with production-safe data.
- A production probe request confirmed Rails logged the real client IP in `request.remote_ip` behind Kamal Proxy.
- Backup and restore are handled as server-side operations outside the application roadmap.
- The persistent SSH control master used for production checks was torn down afterward.

Do not record magic-link tokens, passkey ceremony data, Rails credentials, database passwords, or API keys in documentation or commits.

Still pending for production-hardening, before broader member invitation:

- Verify Active Storage persistence across a container restart after file-upload workflows exist.

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

## Refreshing development data from production

Use `bin/sync_prod_db` to replace the local development database with a fresh dump of the Post 165 production primary database.

Before running it, stop local Rails processes and establish the documented persistent SSH control master for `178.156.250.235`. The script reads from production with `pg_dump`, recreates `legion_post_tools_development`, restores the dump, and deletes copied sessions, magic links, and passkey credentials.

It does not copy Active Storage files or the production cache/queue databases.

## Verification commands

Run the usual app checks before production deploys:

```bash
bin/rails test
bin/brakeman
bin/rubocop
bin/bundler-audit
```

For deployment-specific checks, also confirm:

- exact host token match with `config/deploy.yml`
- `IdentityAgent none`
- `IdentitiesOnly yes`
- `ControlMaster` / `ControlPersist` / `ControlPath`
- two successful `ssh -o BatchMode=yes 178.156.250.235 'hostname && docker --version'` runs before Kamal
- only run `bin/kamal setup` for first provisioning
- run `bin/kamal deploy` only after SSH preflight succeeds
- if SSH fails, fix `~/.ssh/config` before touching Kamal secrets
- if Kamal opens fresh sessions, inspect `ControlMaster` / `ControlPersist` / `ControlPath`
- if auth tries 1Password identities, verify `IdentityAgent none`
- if auth offers too many keys, verify `IdentitiesOnly yes`
- if runtime secrets fail, inspect `.kamal/secrets`
- if registry auth fails, inspect `KAMAL_REGISTRY_PASSWORD`
- a real sign-in email reaches inbox
- a passkey sign-in works at `APP_HOST`
- storage survives a container restart
- restore rehearsal evidence exists for the install
