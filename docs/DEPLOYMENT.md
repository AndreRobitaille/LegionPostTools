# Deployment

Operator guide for Post 165 and repeat maintainer-hosted installs.

Follow the [shared Hetzner deployment agreement](SHARED_HOST_DEPLOYMENT.md) for the
common operator sequence, authorization, transport and failure rules. This guide
owns LegionPostTools' installation details, secrets, worker/mobile checks and backups.
The [local alignment record](deployment/2026-11-01-shared-host-alignment.md) distinguishes
the current uncommitted tooling from committed and production evidence.

## Production model

LegionPostTools is deployed one app/database set per post or unit. Do not combine multiple posts into one Rails database.

The app is not a SaaS or multi-tenant platform. Each installation gets its own Kamal service, image, databases, and storage.

## First production host

- Hostname: `members.wipost165.org`
- Server: shared Hetzner VPS `178.156.250.235`
- Co-hosted apps: `TwoRiversReporter` and the public `wipost165` site
- First production setup: completed for Robert E. Burns Post 165 on July 12, 2026.

Production images are built and tested on isolated GitHub-hosted Linux amd64
runners. Publication and deployment are separate, explicitly authorized maintainer
actions. CI has no registry write permission, production credentials, member data
or SSH access. There is no on-server build fallback.

## Build, publish, deploy

1. Review and commit the intended source changes, complete application CI, and push
   only when authorized. `bin/release push` verifies the exact remote SHA. Pushing
   does not publish or deploy. `bin/release check` is local-only.
2. **Build production image** runs for master pushes, relevant PRs and manual
   dispatches. Select a successful push/manual run for the exact reviewed HEAD.
   It tests the actual image with synthetic inputs and disposable PostgreSQL 17,
   then exports `production-image-<full SHA>`. PR uploads contain checks only.
3. On a clean checkout of that revision, explicitly publish with
   `bin/publish-image ACTIONS_RUN_ID`. This needs authenticated `gh` and `crane`
   (or `CRANE=/path/to/crane`), not a Docker daemon. It checks the workflow run,
   checksums, archive configuration, revision, service, platform and successful
   smoke evidence before authenticating. It decompresses the Docker archive and
   pushes only the full-SHA tag to the existing GHCR repository. Temporary registry
   credentials are removed on success or failure. Record its
   `RELEASE_IMAGE_DIGEST=sha256:...` output.
4. Only after deployment is explicitly authorized, open `bin/release session` with
   host access. It owns one persistent SSH master from preflight through final
   verification. Inspect its resource snapshot and coordinate with the other apps.
   Keep headroom for image extraction and overlapping old/new app containers.
5. In that same shell, set the verified digest and deploy:

   ```bash
   export RELEASE_IMAGE_DIGEST=sha256:<verified-registry-manifest-digest>
   release_deploy
   ```

   The wrapper requires a clean, exactly pushed HEAD, pulls and validates the image,
   and uses `--skip-push --version <HEAD>`. The executable pre-deploy hook checks
   digest, revision, service and linux/amd64 again **after Kamal's final pull,
   before container replacement**. Missing evidence, a stale revision, failed
   pull, changed tag or lost tunnel stops the operation. The pre-build hook also
   refuses implicit builds. Never bypass these hooks.
6. `release_verify` checks the expected revision in the running container name,
   unchanged cohost web/Legion database container IDs and all three sites. Inspect
   the actual running image identity separately. Also inspect authorized Jobs
   worker heartbeat, queue depth, migration results and affected user workflows.
   HTTP success alone does not establish job health or member satisfaction. Use `release_ssh '...'`
   for authorized host checks and `release_kamal app details` for additional Kamal
   diagnostics in the same shell. The helper checks the existing master, injects
   its generated config and refuses caller-supplied `-c`/`--config-file` options.
   It does not open a replacement connection or authorize a mutation. Exit only
   after final verification; exit closes the owned master.

Standalone `deploy`, `push-deploy` and `setup` are disabled. Publication needs its
own authorization; a merge or push does not authorize publication or deployment.
The manifest digest is neither a Git SHA nor an archive checksum. See
[image build and evidence details](PRODUCTION_IMAGE_BUILD.md) and the
[implementation design](deployment/2026-11-01-off-server-image-build-design.md).

## Shared-host safeguards

No compilation runs on the production VPS. Preserve serial Bundler (`--jobs 1`)
and Bootsnap (`-j 1`) compilation within the isolated runner's verified 1,536 MiB
BuildKit memory and memory-plus-swap ceiling. Each build uses a fresh builder and
records cgroup peak/events. An OOM fails the build; it does not authorize raising caps.

Production still needs memory for extraction, migrations and container overlap.
Preflight prints `free -m`, memory pressure and container stats through the retained
tunnel. Use available RAM, not just free RAM; postpone if headroom is absent or
pressure sustained. Coordinate **one deployment at a time** across the three apps.
Check `members.wipost165.org/up`, `tworiversmatters.com` and `wipost165.org` before
and after replacement. Keep service, database, volume, image and proxy identities.

The October 29 server-build outage and cap on the old remote BuildKit container
are historical observations. They do not authorize using that builder again,
raising application capacity or rebooting. Synthetic image smokes do not establish
upgrade safety for every historical database; review migrations and backups before
an authorized release.

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
- `APP_TIME_ZONE`
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

AI minutes drafting reads `openai_access_token` from Rails encrypted credentials. Add it
with `VISUAL=nvim bin/rails credentials:edit`; never edit `config/credentials.yml.enc`
directly and never put the token in `.env`, Kamal clear environment values, documentation,
or Git output. The encrypted credentials file is deployed with the application image and
production's `RAILS_MASTER_KEY` decrypts it, so a separate production edit is unnecessary
when development and production intentionally share that credentials file and master key.
An installation may instead supply `OPENAI_ACCESS_TOKEN` or `OPENAI_API_KEY` as a Kamal
secret, but use only one deliberate source.

Optional clear tuning values are `OPENAI_MINUTES_MODEL` (default `gpt-6-astra`),
`OPENAI_MINUTES_REASONING_EFFORT` (default `high`),
`OPENAI_MINUTES_TEXT_VERBOSITY` (default `medium`), and
`OPENAI_MINUTES_TIMEOUT_SECONDS` (default `60` per HTTP request). The separate
`MINUTES_DRAFT_GENERATION_TIMEOUT_SECONDS` (default `1800`) bounds the whole generation.
Do not lower the model merely to reduce cost without evaluating representative Post
transcripts.

Both OpenAI providers disable implicit prompt cache writes. Endeavor History processes
recorded attestation revisions and retains existing published evidence; a release must
not initiate an archive rebuild or backfill. Officers explicitly authorize paid older-minute
searches through **Search past minutes** (API `operation: refresh`, `cost_acknowledged: true`).
Daily-token-budget failures stay stopped after midnight. No migration or new configuration
is needed for these [spend controls](ENDEAVOR_HISTORY_SPEND_CONTROL.md).

For Astra, use supported reasoning (`low` or higher), not `none` or `minimal`.
The provider uses Responses background mode with no tools, strict JSON output, and
`store: false`; do not add sampling/logprob parameters. Existing model overrides remain intentional
installation choices. See `docs/AGENT_ENVIRONMENT.md` for migration verification limits.

AI drafting runs through Solid Queue and may take several minutes. Production must keep a
Solid Queue worker active (`SOLID_QUEUE_IN_PUMA=true` in the current single-host profile,
or a separately configured worker). After deployment, use **Administration -> Jobs** or
`GET /api/jobs` with an authorized account to verify worker heartbeat, queue depth, and
durable run state. Retrying a failed minutes run creates a linked attempt; discarding only
removes it from the attention list and does not erase history.

Minutes generation records OpenAI's response ID immediately, then polls that same response
in short jobs ten seconds apart. SDK retries are disabled; an interrupted status check
may retry retrieval within the generation deadline, but never submits a replacement
generation. A lost initial submission response still fails explicitly, because its remote
outcome is unknown. No migration or new worker service is required.

`store: false` does not imply zero retention: OpenAI temporarily stores background response
data for polling (roughly ten minutes), and ordinary abuse-monitoring controls may still
apply. Live background-mode acceptance remains unverified until an authorized generation.
See [the generation design](MINUTES_DRAFT_BACKGROUND_GENERATION.md) and
[OpenAI background mode](https://developers.openai.com/api/docs/guides/background).

For Post 165, `DB_HOST` should point at the Kamal Postgres accessory hostname on the Docker network.

`APP_TIME_ZONE` controls local meeting entry, display, and local-day boundaries; Rails
stores timestamps in UTC. Set it to the same Rails or IANA zone selected for the
Organization during setup. Post 165 uses `America/Chicago`. Migration `20260830020000`
performs the one-time conversion of agendas created while Rails still interpreted entered
wall times as UTC. Changing an established installation's zone later requires a previewed
data migration; it is not a routine configuration toggle.

## Persistent SSH control master

SSH credentials stay in the maintainer's OpenSSH configuration and a normal private
key file, never Kamal secrets or CI. The Post 165 host token remains `178.156.250.235`,
with `User root`, a readable `IdentityFile`, `IdentityAgent none` and `IdentitiesOnly
yes`. Optional `RELEASE_SSH_CONFIG` selects a different local config. Do not invent
certificate authentication or alter system-file ownership based on a sandbox view.

`bin/release session` creates a private temporary directory and owns a unique
ControlPath. It uses `ControlMaster=yes` without `-M` (combining both can select
confirmation mode). Kamal's temporary `proxy_command` forwards Net::SSH through
this same outer master. Commands check the master first; `ControlMaster=no` and
`ProxyCommand=false` prevent a silent direct connection if it disappears. The
release wrapper never configures a production builder.

Both internal Kamal commands and additional authorized `release_kamal ...` commands
use the generated session config. Use `release_deploy` for normal deployment so
the reviewed version, digest checks and `--skip-push` path stay together.

The shell stays open after failed commands for diagnosis; this does not authorize
retrying. If SSH fails, stop. Wait at least five minutes before **one explicitly
chosen replacement attempt**. Never use direct/parallel SSH, reconnect loops or a
second session as a fallback. Exit only when the whole operation is finished.
The old `RELEASE_KEEP_SSH_MASTER` switch is superseded by session ownership.

## Postgres accessory

The Postgres accessory uses `config/postgres/init.sh`, not `init.sql`, to create the cache and queue databases from environment variables.

The database data is persisted through the Kamal accessory `directories:` entry:

`legion_post_165_wi_tools_pgdata:/var/lib/postgresql/data`

Treat this as the accessory's persistent directory. Active Storage uses the Docker volume `legion_post_165_wi_tools_storage`.

## Email and WebAuthn

- `MAIL_PROVIDER=loops` uses the Loops transactional API and is the preferred/default Post 165 path.
- Set `LOOPS_API_KEY` and `LOOPS_MAGIC_LINK_TEMPLATE_ID` when using Loops.
- Templates created for Post 165 must use **commander@mail.wipost165.org** as From.
  Set the Loops sender username to `commander`; its account supplies the sending domain.
  Keep Reply-to on the configured monitored address. Do not create `no-reply` templates
  for this installation.
- The selected transactional template must accept scalar `name`, `login_url`, and
  `login_code` variables and present the code and continuation link in one email.
- The Loops backend validates provider success responses, uses short network timeouts,
  and logs acceptance or a safe delivery error without logging the recipient or credentials.
- `MAIL_PROVIDER=action_mailer` uses Action Mailer/SMTP for production email.
- `WEBAUTHN_ORIGIN` must be the HTTPS origin, such as `https://members.wipost165.org`.
- `WEBAUTHN_RP_ID` must be the exact host for this deployment, such as `members.wipost165.org`, without scheme or port. Future operators may choose a parent registrable domain only if they deliberately want credentials to work across subdomains.
- `WEBAUTHN_RP_NAME` should be the post or app display name.

Passkeys require HTTPS and do not work by IP address.

### Minutes distribution and Loops lists

Post 165 activated automatic PEC and monthly membership minutes email on October 19, 2026,
after deployment of `7d60cca71efda7883958f6758530afee3fe21e5d` (PR #159). Loops support
confirmed transactional PDF attachments are enabled. The
[live setup record](MINUTES_EMAIL_DISTRIBUTION.md#post-165-live-setup-verified-october-19-2026)
contains the three private list IDs, published template, selected meeting types and dated
activation evidence. Keep these installation values in saved settings; an ordinary deploy
must not recreate lists, replace recipient entries or re-enroll opted-out contacts.

- **Post members** receives general campaigns and is the only list managed by roster sync.
- **Minutes recipients** receives automatic minutes only for active, explicitly enrolled
  website office entries. Maintain them through **Officer tools → Minutes distribution**.
- **Post officers** is reserved for future use and has no automatic application sync.

General campaigns must select Post members rather than All audience, including newly
created or duplicated campaigns. The existing unsent campaign and inactive sample workflow
were retargeted during activation; sent history was left unchanged. Roster import and
**Sync email audience** do not send campaigns or minutes.

The minutes worker uses `LOOPS_API_KEY` directly and requires the existing Chromium PDF
runtime, a live Solid Queue worker/scheduler and `MinutesDistributionReconcileJob` every
15 minutes. Its selected template is saved on Minutes distribution, separate from
`LOOPS_MAGIC_LINK_TEMPLATE_ID`. `MAIL_PROVIDER=action_mailer` does not supply an SMTP
fallback for this minutes feature. A deploy or enabling the setting creates no historical
mailings. Initial activation was verified without sending real test or historical emails.
The later authorized styled-email test, recipient feedback and sender correction are
recorded in the live setup guide; the sender correction itself sent no additional email.

### Buddy Checks for iPhone

Post 165's mobile profile uses the permanent `https://members.wipost165.org`
issuer, public client `org.wipost165.buddychecks`, exact callback
`org.wipost165.buddychecks:/oauth/callback` and `buddy_check` scope. The clear
settings in `config/deploy.yml` enable Buddy Checks and Contacts projection;
each exporting human additionally needs `export_buddy_contacts`, maintained
under the person's Permissions. Administration and assignments do not imply it.
The current `use_mobile_buddy_checks` pilot grant is required for mobile sign-in,
API access and phone-related website controls. Initial launch grants both only to
Andre; other members and officers see no phone-related links. Current membership
authority is still required for evidence maintenance. Existing role-grant controls
can deliberately assign the pilot capability later.

For explicitly authorized initial activation, run
`BUDDY_CHECK_ACTIVATE_EMAIL=commander@wipost165.org bin/release session`, then
set the verified `RELEASE_IMAGE_DIGEST` and run `release_deploy` in that shell.
The wrapper's preflight, deployment, client registration, narrow user grant and
before/after read-only readiness probes share its persistent SSH master. Probes
print public configuration and server-computed table fingerprints, never member
rows or tokens. They verify the three mobile migrations and compatible secretless
registration. This optional activation never runs on an ordinary release and
therefore cannot silently restore a revoked permission. The initial activation
used 900-second access, explicit consent and no refresh tokens; that legacy flow
remains supported. The separately authorized [remembered sign-in extension](MOBILE_REMEMBERED_SIGN_IN.md)
adds explicit 180-day opt-in while retaining short access tokens. Its
[release handoff](MOBILE_REMEMBERED_SIGN_IN_HANDOFF.md) records migration, validation
and approval status. See also the [initial activation handoff](MOBILE_BUDDY_CHECK_PRODUCTION_READINESS.md).

## Provisioning

Post 165 was already provisioned on July 12, 2026; ordinary releases must not run
setup or recreate its accessory, databases, storage or proxy. A new installation
requires a separately reviewed install profile, unique identities and explicit
provisioning authority. Adapt image labels, publisher and release constants to that
profile, retain off-server builds and digest checks, and plan initial accessory/setup
steps before connecting. Do not use raw build-and-deploy commands as a shortcut.

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
- A production passwordless login email was delivered to `andre@xyzmodem.com` through Loops.
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
5. Review the install-specific provisioning plan; subsequent releases use the
   tested-image publication and owned release session above.
6. Keep storage and database backups scoped to that install only.

## Backups and restore expectations

- Back up the Postgres accessory data and the Active Storage volume separately.
- Preserve the install-specific database names for restores.
- Rehearse restores before depending on them in production; record a restore rehearsal for each install.
- A restore should bring back the primary database first, then cache/queue if needed, then Active Storage files.
- Do not assume another post's backup can be mixed into this install.

## Refreshing development data from production

Only with explicit authority to copy real member data, use `bin/sync_prod_db` to replace the local development database with a fresh dump of the Post 165 production primary database.

The script reads from production with `pg_dump`, recreates
`legion_post_tools_development`, restores the dump, and deletes copied sessions,
magic links, and passkey credentials. Local Rails processes must be stopped
before any authorized replacement of development data.

The current script still uses bare SSH and does not select the owned release
session's private socket. Its transport needs alignment before use under the
shared agreement; do not run it through a separate connection during a release.
This is deferred tooling work, not authorization to copy member data.

It does not copy Active Storage files or the production cache/queue databases.

When Codex runs this command, it must use host access outside the restricted command sandbox. The sandbox can remap root-owned OpenSSH configuration files to `nobody:nobody`, causing OpenSSH 10.5 to report `Bad owner or permissions` even though the host files are correctly owned by `root:root`. Verify system-file ownership outside the sandbox; do not change host ownership based on the sandbox view.

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
- passing local release checks and offline script tests
- successful application CI and image workflow for the exact reviewed SHA
- explicit manual publication, checked artifact and recorded manifest digest
- one owned release session from preflight through final verification
- host headroom, protected container identities, worker health and all three sites
- if SSH fails, fix `~/.ssh/config` before touching Kamal secrets
- if the master fails, stop and apply the five-minute cooldown; do not reconnect automatically
- if auth tries 1Password identities, verify `IdentityAgent none`
- if auth offers too many keys, verify `IdentitiesOnly yes`
- if runtime secrets fail, inspect `.kamal/secrets`
- if registry auth fails, inspect `KAMAL_REGISTRY_PASSWORD`
- a real sign-in email reaches the inbox and both its code and link paths work
- a passkey sign-in works at `APP_HOST`
- storage survives a container restart
- restore rehearsal evidence exists for the install

## Public publishing configuration

The website-token-authenticated publishing API uses `PUBLIC_PUBLISHER_ORIGIN` for absolute portrait
URLs, falling back to `https://` plus the existing `APP_HOST`. Use one HTTPS origin
without a trailing slash or path. A missing/invalid configuration yields a no-store
503; it does not invent an empty collection. `PUBLIC_PUBLISHER_UNAVAILABLE=1` is an
optional maintenance switch that also returns no-store 503 with Retry-After: 60.

The publishing migration creates no grants or published content. The installation
owner must separately authorize initial `publish_public_content` user or office
grants and real content publication. `manage_settings` does not imply publishing.
Create a Post-owned credential under Admin → Website connections and install it in
the public website's server-side secret storage. This credential has fixed read-only
website access; it is not a role or personal agent token. No credentials are created
by the migration. See [Website connections](WEBSITE_CONNECTIONS.md).

All `/public/v1` requests, including portraits and conditional reads, require the
website bearer token. The consumer must support the new `private` cache policy,
credential-separated server caching, and serving portraits through its own routes
before a coordinated release. Purge prior anonymous responses from shared caches;
otherwise they can remain usable for their remaining 300-second lifetime.

Do not configure a shared proxy/CDN cache for this API. The consumer's private
cache must honor the remaining 300-second age, fail closed on authentication
failure and never serve expired content on other failures. Do not cache errors or
route portraits around Rails. Portraits
are private database WebP renditions, not public Active Storage originals. Account
for this small bounded media storage in ordinary PostgreSQL backups. Current
portrait input limits are 10 MiB / 40 megapixels; no original upload is retained.

Local synthetic access, consumer accommodation, and verification are documented
in [the publisher handoff](PUBLIC_PUBLISHING_HANDOFF.md). Production proxy/TLS
behavior and live publication remain separate release verification work.
