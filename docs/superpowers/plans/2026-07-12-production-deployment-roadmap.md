# Production Deployment Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the deployment roadmap design into concrete Post 165 Kamal configuration, Postgres accessory setup, and operator documentation for a safe first production rehearsal on `members.wipost165.org`.

**Architecture:** Use one separate Kamal/Rails installation per American Legion post or unit. The first installation is Post 165 on the existing shared Hetzner VPS, with unique service, image, PostgreSQL databases, Docker volumes, and secrets. Deployment remains CLI-driven from the local repository with mandatory persistent SSH control-master discipline before production Kamal operations.

**Tech Stack:** Rails 8.1, PostgreSQL 17 container accessory, Docker, Kamal, Kamal Proxy, GHCR, Solid Queue in Puma, Active Storage local volume, WebAuthn/passkeys, magic-link email.

---

## File Structure

- Modify `config/deploy.yml`: replace the Rails scaffold values with the Post 165 production Kamal profile, including unique names, proxy host, GHCR registry, app env, Active Storage volume, and PostgreSQL accessory.
- Modify `config/database.yml`: use a small ERB helper so production fails fast for `POSTGRES_DB`, `POSTGRES_CACHE_DB`, `POSTGRES_QUEUE_DB`, and `DB_HOST`, while development/test can still parse the production block with safe generic fallbacks.
- Create `config/postgres/init.sh`: create Rails cache and queue production databases for the dedicated Post 165 Postgres accessory.
- Modify `docs/DEPLOYMENT.md`: expand the deployment guide into a Post 165 first-deploy checklist and repeatable maintainer-hosted install guide.
- Modify `docs/ROADMAP.md`: add a side-roadmap section for production readiness before or alongside Structured Agendas.
- Keep `AGENTS.md` and `CLAUDE.md`: preserve the already-added SSH throttling/control-master rule; only edit if wording needs to match the deployment guide.

---

### Task 1: Configure production database connection for a Kamal Postgres accessory

**Files:**
- Modify: `config/database.yml:87-100`

- [ ] **Step 1: Inspect the current production database block**

Run:

```bash
ruby -rerb -e 'puts ERB.new(File.read("config/database.yml")).result.lines.grep(/production:|primary:|database: legion_post_tools_production|username: legion_post_tools|password:|host:/)'
```

Expected: output includes the production primary database, username, and password, but no production `host:` line.

- [ ] **Step 2: Add production env helper and host setting**

Edit `config/database.yml` so it starts with this helper:

```erb
<% production_config = ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "development")) == "production" %>
<% required_production_env = ->(name, fallback) { ENV.fetch(name) { production_config ? raise(KeyError, "key not found: #{name}") : fallback } } %>
```

Then make the production block exactly:

```yaml
production:
  primary: &primary_production
    <<: *default
    database: <%= required_production_env.call("POSTGRES_DB", "legion_post_tools_production") %>
    username: legion_post_tools
    password: <%= ENV["LEGION_POST_TOOLS_DATABASE_PASSWORD"] %>
    host: <%= required_production_env.call("DB_HOST", "localhost") %>
  cache:
    <<: *primary_production
    database: <%= required_production_env.call("POSTGRES_CACHE_DB", "legion_post_tools_production_cache") %>
    migrations_paths: db/cache_migrate
  queue:
    <<: *primary_production
    database: <%= required_production_env.call("POSTGRES_QUEUE_DB", "legion_post_tools_production_queue") %>
    migrations_paths: db/queue_migrate
```

This task must not hard-code Post 165 database names in `config/database.yml`.

- [ ] **Step 3: Verify database YAML still parses after ERB rendering**

Run:

```bash
ruby -rerb -ryaml -e 'YAML.safe_load(ERB.new(File.read("config/database.yml")).result, aliases: true); puts "database.yml OK"'
```

Expected: `database.yml OK`.

- [ ] **Step 4: Commit the database host change**

Run only if commits are authorized for this execution session:

```bash
git add config/database.yml
git commit -m "config: allow production database host override"
```

Expected: commit succeeds with only `config/database.yml` staged.

---

### Task 2: Add Post 165 Postgres accessory initialization SQL

**Files:**
- Create: `config/postgres/init.sh`

- [ ] **Step 1: Create the Postgres initialization directory**

Run:

```bash
mkdir -p config/postgres
```

Expected: `config/postgres` exists.


- [ ] **Step 2: Create the init shell script**

Write `config/postgres/init.sh` as the robust PostgreSQL bootstrap used by the production accessory. It should use `psql -v` variables and quoted identifiers, not raw `CREATE DATABASE "$POSTGRES_CACHE_DB"` statements.

The script should:

- create the cache and queue databases with `psql -v ON_ERROR_STOP=1 -v cache_db=... -v queue_db=...`
- use `CREATE DATABASE :"cache_db"` and `CREATE DATABASE :"queue_db"`
- quote identifiers so the script is safe if names ever contain special characters

- [ ] **Step 3: Verify the bootstrap script uses psql variables**

Run:

```bash
ruby -e 'script = File.read("config/postgres/init.sh"); abort("missing psql variable form") unless script.include?("-v cache_db") && script.include?("CREATE DATABASE :\"cache_db\""); puts "postgres init script OK"'
```

Expected: `postgres init script OK`.

- [ ] **Step 4: Commit the Postgres init SQL**

Run only if commits are authorized for this execution session:

```bash
git add config/postgres/init.sh
git commit -m "config: add production postgres init script"
```

Expected: commit succeeds with only `config/postgres/init.sh` staged.

---

### Task 3: Update Kamal deploy profile for Post 165

**Files:**
- Modify: `config/deploy.yml`

- [ ] **Step 1: Replace the scaffolded deploy profile**

Edit `config/deploy.yml` to exactly this content, preserving the production server IP already used by TwoRiversReporter:

```yaml
# Post 165 production profile.
# This install is one separate Kamal/Rails application for Robert E. Burns Post 165.
service: legion_post_165_wi_tools
image: andrerobitaille/legion-post-165-wi-tools

servers:
  web:
    - 178.156.250.235

proxy:
  ssl: true
  host: members.wipost165.org

registry:
  server: ghcr.io
  username: AndreRobitaille
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
    - LEGION_POST_TOOLS_DATABASE_PASSWORD
    - LOOPS_API_KEY
    - LOOPS_MAGIC_LINK_TEMPLATE_ID
  clear:
    SOLID_QUEUE_IN_PUMA: true
    DB_HOST: legion_post_165_wi_tools-db
    POSTGRES_DB: legion_post_165_wi_tools_production
    POSTGRES_CACHE_DB: legion_post_165_wi_tools_production_cache
    POSTGRES_QUEUE_DB: legion_post_165_wi_tools_production_queue
    WEB_CONCURRENCY: 2
    RAILS_LOG_LEVEL: info
    APP_HOST: members.wipost165.org
    MAIL_PROVIDER: loops
    MAIL_FROM: no-reply@wipost165.org
    WEBAUTHN_ORIGIN: https://members.wipost165.org
    WEBAUTHN_RP_ID: members.wipost165.org
    WEBAUTHN_RP_NAME: LegionPostTools

aliases:
  console: app exec --interactive --reuse "bin/rails console"
  shell: app exec --interactive --reuse "bash"
  logs: app logs -f
  dbc: app exec --interactive --reuse "bin/rails dbconsole --include-password"

volumes:
  - "legion_post_165_wi_tools_storage:/rails/storage"

asset_path: /rails/public/assets

builder:
  arch: amd64

accessories:
  db:
    image: postgres:17
    host: 178.156.250.235
    port: "127.0.0.1:5433:5432"
    env:
      clear:
        POSTGRES_DB: legion_post_165_wi_tools_production
        POSTGRES_USER: legion_post_tools
        POSTGRES_CACHE_DB: legion_post_165_wi_tools_production_cache
        POSTGRES_QUEUE_DB: legion_post_165_wi_tools_production_queue
      secret:
        - POSTGRES_PASSWORD:LEGION_POST_TOOLS_DATABASE_PASSWORD
    files:
      - config/postgres/init.sh:/docker-entrypoint-initdb.d/init.sh
    directories:
      - legion_post_165_wi_tools_pgdata:/var/lib/postgresql/data
```

Notes for the implementer:

- The host IP matches the existing shared Hetzner VPS.
- The accessory port uses host port `5433` to avoid conflicting with TwoRiversReporter, which binds `127.0.0.1:5432:5432`.
- The app should connect over the Kamal Docker network using `DB_HOST: legion_post_165_wi_tools-db`, not through the host port.
- `MAIL_FROM` may be changed before deployment if Andre chooses a different sender, but the value must stay explicit in the deploy profile.
- The Postgres accessory uses Kamal secret aliasing so the container receives `POSTGRES_PASSWORD` from the same `LEGION_POST_TOOLS_DATABASE_PASSWORD` secret Rails uses.

- [ ] **Step 2: Verify deploy YAML parses**

Run:

```bash
ruby -ryaml -e 'YAML.safe_load(File.read("config/deploy.yml"), aliases: true); puts "deploy.yml OK"'
```

Expected: `deploy.yml OK`.

- [ ] **Step 3: Verify critical deploy values are present**

Run:

```bash
ruby -ryaml -e 'y = YAML.safe_load(File.read("config/deploy.yml"), aliases: true); abort("wrong service") unless y["service"] == "legion_post_165_wi_tools"; abort("wrong host") unless y.dig("proxy", "host") == "members.wipost165.org"; abort("wrong db host") unless y.dig("env", "clear", "DB_HOST") == "legion_post_165_wi_tools-db"; abort("missing accessory") unless y.dig("accessories", "db", "directories")&.include?("legion_post_165_wi_tools_pgdata:/var/lib/postgresql/data"); puts "deploy profile values OK"'
```

Expected: `deploy profile values OK`.

- [ ] **Step 4: Commit the deploy profile**

Run only if commits are authorized for this execution session:

```bash
git add config/deploy.yml
git commit -m "config: prepare post 165 kamal deployment"
```

Expected: commit succeeds with only `config/deploy.yml` staged.

---

### Task 4: Align production database configuration with the Post 165 install identity

**Files:**
- Modify: `config/database.yml:87-101`


- [ ] **Step 1: Update the production ERB helper and env lookups**

The final design keeps the production config flexible while still failing fast in production when required env vars are missing. The ERB helper in `config/database.yml` should be:

```ruby
production_config = ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "development")) == "production"
required_production_env = ->(name, fallback) { ENV.fetch(name) { production_config ? raise(KeyError, "key not found: #{name}") : fallback } }
```

The production block should then use:

- `required_production_env.call("POSTGRES_DB", "legion_post_tools_production")`
- `required_production_env.call("POSTGRES_CACHE_DB", "legion_post_tools_production_cache")`
- `required_production_env.call("POSTGRES_QUEUE_DB", "legion_post_tools_production_queue")`
- `required_production_env.call("DB_HOST", "localhost")`

and keep the existing password lookup for the application database credentials.

- [ ] **Step 2: Verify the production configuration shape**

Run:

```bash
ruby -rerb -ryaml -e 'config = YAML.safe_load(ERB.new(File.read("config/database.yml")).result, aliases: true); prod = config.fetch("production"); names = [prod.dig("primary", "database"), prod.dig("cache", "database"), prod.dig("queue", "database")]; expected = ["legion_post_tools_production", "legion_post_tools_production_cache", "legion_post_tools_production_queue"]; abort("wrong database names: #{names.inspect}") unless names == expected; puts "production database configuration OK"'
```

Expected: `production database configuration OK`.

- [ ] **Step 3: Commit the production database configuration**

Run only if commits are authorized for this execution session:

```bash
git add config/database.yml
git commit -m "config: use production env helpers for database settings"
```

Expected: commit succeeds with only `config/database.yml` staged.

- [ ] **Step 4: Document the deploy environment and regression test responsibilities**

The deploy profile supplies the Post 165 `POSTGRES_*` values, including `POSTGRES_DB`, `POSTGRES_CACHE_DB`, `POSTGRES_QUEUE_DB`, `DB_HOST`, and the credentials consumed by the app.

The regression test in `test/config/database_configuration_test.rb` covers both non-production parsing and the production fail-fast behavior when required env vars are absent.

---

### Task 5: Expand deployment documentation for Post 165 and repeat hosted installs

**Files:**
- Modify: `docs/DEPLOYMENT.md`

- [ ] **Step 1: Replace the scaffold-focused deployment notes with the proven roadmap guide**

Edit `docs/DEPLOYMENT.md` so it contains this complete document:

```markdown
# Deployment

This document records the production deployment path for LegionPostTools. The first production installation is Robert E. Burns Post 165 at `members.wipost165.org`.

LegionPostTools is deployed as one separate application per American Legion post or unit. It is not a SaaS or multi-tenant application.

## Production Target

- Hostname: `members.wipost165.org`.
- Server: shared Hetzner VPS at `178.156.250.235`.
- Deployment tool: Kamal from the local repository.
- Registry: GHCR.
- Database: dedicated PostgreSQL accessory container for this install.
- Storage: dedicated Docker volume mounted at `/rails/storage`.
- Background jobs: Solid Queue runs in Puma for the first single-server deployment.

The same VPS already hosts TwoRiversReporter. Do not assume LegionPostTools is the only app on the server.

## SSH Discipline

The Hetzner VPS throttles repeated SSH connections heavily. Before running Kamal or other SSH-heavy production operations, establish a persistent SSH control master and route Kamal through it. Tear it down when production work is finished.

Do not run repeated fresh SSH or Kamal commands directly against the production box.

A safe workflow is:

```bash
mkdir -p ~/.ssh/controlmasters
ssh -MNf -o ControlMaster=yes -o ControlPersist=30m -o ControlPath=~/.ssh/controlmasters/%r@%h:%p root@178.156.250.235
```

Then ensure SSH and Kamal commands use the same `ControlPath` through SSH config or command options. When finished:

```bash
ssh -O exit -o ControlPath=~/.ssh/controlmasters/%r@%h:%p root@178.156.250.235
```

## Naming Rules

Use install-specific names:

```text
legion_<unit_type>_<unit_number>_<department_abbreviation>_tools_<purpose>
```

The Department abbreviation is the American Legion state-level Department abbreviation, such as `wi`.

For Post 165:

| Resource | Name |
| --- | --- |
| Kamal service | `legion_post_165_wi_tools` |
| Container image | `andrerobitaille/legion-post-165-wi-tools` |
| Primary database | `legion_post_165_wi_tools_production` |
| Cache database | `legion_post_165_wi_tools_production_cache` |
| Queue database | `legion_post_165_wi_tools_production_queue` |
| Postgres volume | `legion_post_165_wi_tools_pgdata` |
| Active Storage volume | `legion_post_165_wi_tools_storage` |

Use unique names for every future hosted post or unit. Do not reuse databases, volumes, service names, or hostnames across installs.

## Required Production Environment

Kamal secrets must provide:

- `RAILS_MASTER_KEY`.
- `KAMAL_REGISTRY_PASSWORD`.
- `LEGION_POST_TOOLS_DATABASE_PASSWORD`.
- `LOOPS_API_KEY`.
- `LOOPS_MAGIC_LINK_TEMPLATE_ID`.

The PostgreSQL accessory maps its container `POSTGRES_PASSWORD` environment variable from `LEGION_POST_TOOLS_DATABASE_PASSWORD` using Kamal secret aliasing. Keep one database password secret per install.

Kamal clear env currently provides:

- `APP_HOST=members.wipost165.org`.
- `MAIL_PROVIDER=loops`.
- `MAIL_FROM=no-reply@wipost165.org`.
- `WEBAUTHN_ORIGIN=https://members.wipost165.org`.
- `WEBAUTHN_RP_ID=members.wipost165.org`.
- `WEBAUTHN_RP_NAME=LegionPostTools`.
- `DB_HOST=legion_post_165_wi_tools-db`.
- `SOLID_QUEUE_IN_PUMA=true`.

Passkeys require HTTPS and the browser origin must match the WebAuthn values exactly.

## Email

Email delivery is behind the `MailDelivery` seam (`app/services/mail_delivery.rb`). Production uses `MAIL_PROVIDER=loops` unless deliberately changed.

For Loops.so:

- Create a transactional template in Loops.
- The template must reference `{{login_url}}` and `{{name}}`.
- Set `LOOPS_API_KEY` and `LOOPS_MAGIC_LINK_TEMPLATE_ID` in Kamal secrets.
- Send a real sign-in link from production and confirm inbox delivery before onboarding members.

## Post 165 First Deploy Checklist

1. Confirm DNS for `members.wipost165.org` points to `178.156.250.235`.
2. Confirm `config/deploy.yml` uses service `legion_post_165_wi_tools` and proxy host `members.wipost165.org`.
3. Confirm `config/database.yml` uses canonical `POSTGRES_*` env names and `config/deploy.yml` supplies the Post 165 database values.
4. Confirm `config/postgres/init.sh` creates the cache and queue databases.
5. Configure Kamal secrets for Rails, registry, database, and Loops. Use one database password secret, `LEGION_POST_TOOLS_DATABASE_PASSWORD`, for both Rails and the PostgreSQL accessory.
6. Establish the persistent SSH control master.
7. Run `bin/kamal setup` for the first deployment.
8. Confirm `https://members.wipost165.org/up` is healthy.
9. Complete the first-run setup wizard for Post 165.
10. Verify magic-link sign-in.
11. Verify passkey registration and sign-in.
12. Import a real or representative Post 165 roster CSV.
13. Verify administrator access control and person-to-user login management.
14. Create a database backup.
15. Restore that backup into a disposable database or container to confirm the backup is usable.
16. Confirm Active Storage files survive a redeploy.
17. Tear down the persistent SSH control master.

Treat this first deployment as a rehearsal until the acceptance checks pass. If foundational mistakes appear, destroy and recreate the app/database/volumes before inviting members.

## Repeat Hosted Install Checklist

For another post or unit hosted by Andre:

1. Choose a hostname.
2. Choose `unit_type`, `unit_number`, and Department abbreviation.
3. Generate unique service, image, database, and volume names from the naming convention.
4. Add DNS for the hostname.
5. Create a separate Kamal deploy profile or branch-specific deploy configuration.
6. Create separate secrets for that install.
7. Deploy with the same SSH control-master discipline.
8. Run the same production acceptance checks before onboarding that post's members.

Do not combine multiple posts into one Rails database.

## Backups

The Postgres data lives in the Docker volume `legion_post_165_wi_tools_pgdata`. Active Storage files live in `legion_post_165_wi_tools_storage`.

Before member onboarding, there must be a working database backup and a restore rehearsal. A backup that has not been restored is not considered proven.

The backup process should capture at least:

- `legion_post_165_wi_tools_production`.
- `legion_post_165_wi_tools_production_cache` if cache preservation is desired.
- `legion_post_165_wi_tools_production_queue` if queued job preservation is desired.
- Active Storage volume data.

## Verification Before Go-Live

Before declaring production ready, run:

```bash
bin/rails test
bin/brakeman
bin/rubocop
bin/bundler-audit
```

For browser-visible flows, also run a browser smoke test against `https://members.wipost165.org` when practical.

## Deferred Deployment Work

Do not build these before the first Post 165 deployment is proven:

- Multi-tenant SaaS architecture.
- A web installer.
- Generic VPS provisioning automation.
- A polished self-host package.

Later, after Post 165 is live and a repeat deployment is better understood, consider a template-driven install generator for hosted posts.
```

- [ ] **Step 2: Verify the deployment doc mentions the critical safeguards**

Run:

```bash
ruby -e 'doc = File.read("docs/DEPLOYMENT.md"); required = ["members.wipost165.org", "legion_post_165_wi_tools", "persistent SSH control master", "LEGION_POST_TOOLS_DATABASE_PASSWORD", "POSTGRES_PASSWORD", "restore rehearsal", "Do not combine multiple posts into one Rails database"]; missing = required.reject { |s| doc.include?(s) }; abort("missing: #{missing.join(", ")}") unless missing.empty?; puts "deployment doc safeguards OK"'
```

Expected: `deployment doc safeguards OK`.

- [ ] **Step 3: Commit the deployment documentation**

Run only if commits are authorized for this execution session:

```bash
git add docs/DEPLOYMENT.md
git commit -m "docs: document post 165 production deployment"
```

Expected: commit succeeds with only `docs/DEPLOYMENT.md` staged.

---

### Task 6: Add the production side-roadmap to the roadmap

**Files:**
- Modify: `docs/ROADMAP.md`

- [ ] **Step 1: Insert a production readiness section before Structured Agendas**

In `docs/ROADMAP.md`, insert this section before `## Immediate Next: Structured Agendas`:

```markdown
## Production Readiness Side-Roadmap

Before or alongside the Structured Agendas work, prepare the first real production installation for Robert E. Burns Post 165.

- Configure `members.wipost165.org` on the shared Hetzner VPS as a separate Kamal service.
- Use install-specific names such as `legion_post_165_wi_tools` for service, databases, and volumes.
- Use a dedicated PostgreSQL accessory and Active Storage volume for this install.
- Follow persistent SSH control-master discipline before any Kamal or SSH-heavy production work.
- Rehearse production on the real hostname before inviting members.
- Verify HTTPS, WebAuthn/passkeys, magic links, roster import, admin access control, backups, restore, and storage persistence.
- Update deployment documentation so the same pattern can later be repeated for another hosted American Legion post or unit without creating a SaaS/multi-tenant app.
```

- [ ] **Step 2: Verify the roadmap includes production readiness without removing Structured Agendas**

Run:

```bash
ruby -e 'roadmap = File.read("docs/ROADMAP.md"); required = ["## Production Readiness Side-Roadmap", "members.wipost165.org", "## Immediate Next: Structured Agendas"]; missing = required.reject { |s| roadmap.include?(s) }; abort("missing: #{missing.join(", ")}") unless missing.empty?; puts "roadmap production section OK"'
```

Expected: `roadmap production section OK`.

- [ ] **Step 3: Commit the roadmap update**

Run only if commits are authorized for this execution session:

```bash
git add docs/ROADMAP.md
git commit -m "docs: add production readiness roadmap"
```

Expected: commit succeeds with only `docs/ROADMAP.md` staged.

---

### Task 7: Run local configuration and documentation verification

**Files:**
- Verify: `config/deploy.yml`
- Verify: `config/database.yml`
- Verify: `config/postgres/init.sh`
- Verify: `docs/DEPLOYMENT.md`
- Verify: `docs/ROADMAP.md`

- [ ] **Step 1: Parse YAML files**

Run:

```bash
ruby -rerb -ryaml -e 'YAML.safe_load(File.read("config/deploy.yml"), aliases: true); YAML.safe_load(ERB.new(File.read("config/database.yml")).result, aliases: true); puts "YAML verification OK"'
```

Expected: `YAML verification OK`.

- [ ] **Step 2: Verify Post 165 names are consistent across config files**

Run:

```bash
ruby -e 'files = %w[config/deploy.yml config/database.yml config/postgres/init.sh docs/DEPLOYMENT.md docs/ROADMAP.md]; content = files.to_h { |f| [f, File.read(f)] }; required = { "config/deploy.yml" => ["legion_post_165_wi_tools", "members.wipost165.org", "legion_post_165_wi_tools-db", "POSTGRES_DB", "POSTGRES_CACHE_DB", "POSTGRES_QUEUE_DB", "POSTGRES_PASSWORD:LEGION_POST_TOOLS_DATABASE_PASSWORD"], "config/database.yml" => ["required_production_env.call(\"POSTGRES_DB\"", "required_production_env.call(\"POSTGRES_CACHE_DB\"", "required_production_env.call(\"POSTGRES_QUEUE_DB\"", "required_production_env.call(\"DB_HOST\""], "config/postgres/init.sh" => ["POSTGRES_CACHE_DB", "POSTGRES_QUEUE_DB"], "docs/DEPLOYMENT.md" => ["persistent SSH control master", "restore rehearsal", "LEGION_POST_TOOLS_DATABASE_PASSWORD", "POSTGRES_PASSWORD"], "docs/ROADMAP.md" => ["Production Readiness Side-Roadmap"] }; missing = required.flat_map { |file, strings| strings.reject { |s| content.fetch(file).include?(s) }.map { |s| "#{file}: #{s}" } }; abort("missing required content:\n#{missing.join("\n")}") unless missing.empty?; puts "Post 165 deployment content OK"'
```

Expected: `Post 165 deployment content OK`.

- [ ] **Step 3: Run the standard local checks before claiming the branch is ready**

Run:

```bash
bin/rails test
bin/brakeman
bin/rubocop
bin/bundler-audit
```

Expected: all commands pass. If a command fails because a tool is not installed or an advisory database cannot be reached, record the exact failure and ask Andre before bypassing it.

- [ ] **Step 4: Review the final diff**

Run:

```bash
git diff -- config/deploy.yml config/database.yml config/postgres/init.sh docs/DEPLOYMENT.md docs/ROADMAP.md AGENTS.md CLAUDE.md docs/superpowers/specs/2026-07-12-production-deployment-roadmap-design.md docs/superpowers/plans/2026-07-12-production-deployment-roadmap.md
```

Expected: diff only includes the deployment roadmap, deployment configuration, and deployment documentation changes described in this plan.

- [ ] **Step 5: Commit final verification state**

Run only if commits are authorized for this execution session and earlier tasks were not already committed individually:

```bash
git add config/deploy.yml config/database.yml config/postgres/init.sh docs/DEPLOYMENT.md docs/ROADMAP.md AGENTS.md CLAUDE.md docs/superpowers/specs/2026-07-12-production-deployment-roadmap-design.md docs/superpowers/plans/2026-07-12-production-deployment-roadmap.md
git commit -m "docs: plan production deployment readiness"
```

Expected: commit succeeds with only intended deployment-related files staged.

---

## Self-Review

- Spec coverage: The plan covers the one-install-per-post deployment model, Post 165 target hostname, shared Hetzner/Kamal constraints, install-specific naming, dedicated Postgres accessory, Active Storage volume, Solid Queue in Puma, SSH control-master discipline, first-deploy rehearsal, acceptance checks, operator docs, and deferred installer/SaaS work.
- Placeholder scan: No incomplete implementation placeholders are present. Values that can change operationally, such as `MAIL_FROM`, are explicitly called out with current concrete defaults.
- Type and name consistency: The plan consistently uses `legion_post_165_wi_tools`, `members.wipost165.org`, `legion_post_165_wi_tools-db`, `legion_post_165_wi_tools_production`, `legion_post_165_wi_tools_production_cache`, and `legion_post_165_wi_tools_production_queue`. It uses one database password secret, `LEGION_POST_TOOLS_DATABASE_PASSWORD`, with Kamal aliasing to provide `POSTGRES_PASSWORD` to the PostgreSQL container.
