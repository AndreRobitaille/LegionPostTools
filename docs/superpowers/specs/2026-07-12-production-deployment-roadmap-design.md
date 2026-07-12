# Production Deployment Roadmap Design

## Purpose

Prepare LegionPostTools for its first production installation at Robert E. Burns Post 165 while creating a deployment pattern that can later be repeated for other American Legion installations hosted by the maintainer.

The immediate goal is a safe Post 165 launch. The near-term goal is repeatable maintainer-hosted deployments, still with one separate application and database per post or unit. Semi-technical self-hosting and polished installer automation are future possibilities, not current implementation targets.

## Deployment Principle

LegionPostTools is not a SaaS application. Each hosted installation should have its own:

- Kamal service.
- Public hostname.
- Application container/image identity.
- PostgreSQL databases and persistent Postgres volume.
- Active Storage volume.
- Secrets and production environment values.
- Backup and restore process.

The same VPS may host more than one installation, but only at the infrastructure level. Application data is not shared between posts or units.

## First Production Target

The first production deployment is for Robert E. Burns Post 165 in Two Rivers, Wisconsin.

- Hostname: `members.wipost165.org`.
- Server: the existing Hetzner VPS that already hosts TwoRiversReporter.
- DNS: Andre will configure DNS for `members.wipost165.org` before the first real deploy.
- Rehearsal model: `members.wipost165.org` is both the rehearsal hostname and eventual production hostname. It is acceptable to deploy, test, destroy, and recreate the installation there before inviting members.

The app must not hard-code Post 165 details into general application behavior. Post 165 values belong in deployment configuration, first-run setup data, or operator documentation.

## Naming Convention

Hosted installs need collision-resistant names because future deployments may include different posts, Departments, and American Legion Family units such as Auxiliary, Sons of The American Legion, or Legion Riders.

Use this pattern for infrastructure names:

```text
legion_<unit_type>_<unit_number>_<department_abbreviation>_tools_<purpose>
```

The Department abbreviation is the American Legion state-level Department abbreviation, such as `wi`. The `purpose` suffix should identify the concrete resource or environment, such as `production`, `production_cache`, `pgdata`, or `storage`.

For Post 165, use:

| Resource | Name |
| --- | --- |
| Kamal service | `legion_post_165_wi_tools` |
| Container image | `legion-post-165-wi-tools` under the chosen registry account |
| Primary database | `legion_post_165_wi_tools_production` |
| Cache database | `legion_post_165_wi_tools_production_cache` |
| Queue database | `legion_post_165_wi_tools_production_queue` |
| Postgres data volume | `legion_post_165_wi_tools_pgdata` |
| Active Storage volume | `legion_post_165_wi_tools_storage` |

Future examples:

- `legion_post_123_tx_tools_production`.
- `legion_auxiliary_165_wi_tools_production`.
- `legion_sons_165_wi_tools_production`.
- `legion_riders_165_wi_tools_production`.

## Deployment Architecture

Use Kamal from the local repository. The supported workflow is `bin/kamal setup` for first deployment and `bin/kamal deploy` for later deployments. Do not clone the repository onto the production server as the normal deployment workflow, and do not depend on a web UI.

The shared Hetzner VPS already runs TwoRiversReporter. LegionPostTools must be configured as a separate Kamal service with unique names for all shared resources. Kamal proxy routes by hostname:

- `tworiversmatters.com` routes to TwoRiversReporter.
- `members.wipost165.org` routes to LegionPostTools.

For the first deployment, use a dedicated PostgreSQL Kamal accessory for LegionPostTools. Reconsider only if a concrete blocker appears during implementation. The accessory should create the primary database through the canonical `POSTGRES_DB` env var from `config/deploy.yml`, and create the cache and queue databases through `config/postgres/init.sh`.

Use the same registry family as TwoRiversReporter unless there is a concrete reason to change. The expected default is GHCR, with Kamal registry credentials supplied through secrets.

Active Storage uses a dedicated local Docker volume mounted at `/rails/storage`. Solid Queue runs inside Puma with `SOLID_QUEUE_IN_PUMA=true` for the first single-server deployment. A separate job role can be introduced later if production load requires it.

## Production SSH Discipline

The Hetzner VPS throttles repeated SSH connections heavily. Before running Kamal or other SSH-heavy production operations against that server, establish a persistent SSH connection, tunnel, or control master and route the work through it. Tear the persistent connection down when production work is finished.

Repeated fresh SSH or Kamal commands against the production box are not allowed.

This rule belongs in both general agent instructions and deployment documentation so future agents do not accidentally trigger throttling.

## Roadmap Phases

### Phase 1: Production Readiness Design

- Record the deployment model: one installation per post or unit, no SaaS tenancy.
- Record the Post 165 target hostname and shared-server constraints.
- Define install-specific naming conventions.
- Record the SSH control-master requirement.
- Decide the first database approach, with Kamal PostgreSQL accessory as the baseline.

### Phase 2: Post 165 Infrastructure Configuration

- Configure DNS for `members.wipost165.org` to point to the shared Hetzner VPS.
- Update `config/deploy.yml` from scaffold to the Post 165 production profile.
- Configure a unique Kamal service, image name, proxy host, registry, app volume, and PostgreSQL accessory.
- Add a Postgres initialization shell script for cache and queue databases.
- List required secrets and environment variables, including Rails, registry, database, mail, and WebAuthn values.
- Verify names do not conflict with TwoRiversReporter resources.

### Phase 3: First Deploy Rehearsal on the Real Hostname

- Establish the persistent SSH control master before Kamal operations.
- Run the first Kamal setup/deploy flow from the local repository.
- Confirm the app boots, `/up` is healthy, HTTPS is active, logs are usable, migrations run, storage is mounted, and Solid Queue starts.
- Complete first-run setup for Post 165.
- Treat the deployment as disposable until production acceptance passes. If foundational mistakes are found, destroy and recreate the Post 165 app/database/volumes before onboarding members.

### Phase 4: Production Acceptance Checks

- Verify magic-link email delivery using the production mail provider.
- Verify passkey registration and sign-in over `https://members.wipost165.org`.
- Verify WebAuthn origin, relying-party ID, and relying-party name values.
- Import a real or representative Post 165 roster CSV.
- Verify administrator access control and person-to-user login management.
- Run browser smoke tests for sign-in, setup completion, roster administration, and security settings.
- Create a database backup and perform at least one restore rehearsal before inviting members.
- Confirm Active Storage data is preserved across deploys.

### Phase 5: Operator Documentation

Update `docs/DEPLOYMENT.md` after the first path is proven. It should include:

- Post 165 first-deploy checklist.
- Reusable checklist for a future maintainer-hosted post or unit.
- DNS prerequisites.
- Kamal setup/deploy workflow.
- Persistent SSH control-master workflow.
- PostgreSQL accessory and database naming rules.
- Backup and restore expectations.
- Email and WebAuthn production configuration.
- Browser smoke tests before member onboarding.

### Phase 6: Go-Live

- If the rehearsal deployment is sound, keep the database and volumes and declare it official.
- If the rehearsal exposed foundational deployment mistakes, recreate the install before member onboarding.
- Invite initial administrators/officers first.
- Broader member onboarding happens only after authentication, roster import, backups, and restore rehearsal are confirmed.

## Deferred Work

Do not build these now:

- Multi-tenant SaaS architecture.
- A web-based installer.
- Generic VPS provisioning automation.
- A polished self-host package.
- A script that hides important production decisions before one real deployment path is proven.

Later, after Post 165 is live and at least one repeat deployment is understood, consider a template-driven install generator that creates a deploy profile, database names, volume names, and checklist from unit type, unit number, Department abbreviation, hostname, and registry settings.

## Success Criteria

This roadmap succeeds when:

- Post 165 can be deployed to `members.wipost165.org` on the shared Hetzner VPS without conflicting with TwoRiversReporter.
- The database, storage, and Kamal resources are uniquely named for Post 165.
- The deploy flow uses persistent SSH discipline.
- Authentication works over real HTTPS with magic links and passkeys.
- Roster-backed administration works in production.
- Backup and restore have been tested before member onboarding.
- The resulting docs are clear enough for Andre to repeat the pattern for another hosted post without rediscovering the deployment decisions.
