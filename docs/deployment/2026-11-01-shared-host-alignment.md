# Shared-host alignment: local implementation

November 1, 2026. This record covers local work only; it authorizes no release.

The [shared operator agreement](../SHARED_HOST_DEPLOYMENT.md) is copied unchanged
from TwoRiversReporter. No correction to that agreement was needed for this app;
its operator duties must be read alongside the limits below. AGENTS.md and the
deployment guide link to the agreement. App secrets, three database identities,
storage, two Puma workers, Jobs verification, optional mobile activation and
backup/restore expectations remain app-specific.

The session now exports `release_kamal`. It checks the existing owned master and
generated config, refuses caller configuration overrides, preserves argument
boundaries and supplies that config to Kamal. Preflight, image pulls, deployment
and optional mobile activation use it. `release_deploy` retains the explicit
reviewed version, required digest, final-pull hook and `--skip-push`. There was no
previous app-specific Kamal helper alias to retain.

Paths changed by this alignment:

- `AGENTS.md`, `docs/DEPLOYMENT.md`: shared routing and current operator limits.
- `docs/SHARED_HOST_DEPLOYMENT.md`: identical shared agreement.
- `bin/release`, `lib/release_image.sh`: session helper and internal callers.
- `test/scripts/release_test.rb`: routing, argument and lost-session regression checks.
- `docs/deployment/2026-11-01-off-server-image-build-design.md`: bounded design scope.
- `docs/deployment/2026-11-01-shared-host-alignment.md`: this evidence and deferred work.

## Evidence boundary

The audit began at committed `846cacfb77bc7590766274c46a7fbbe12ccfc096` on master
with substantial existing uncommitted release work. That committed release script
still opens SSH for `check`, supports `push-deploy`/keep-master and permits a remote
build without a digest. The local-only check, mandatory off-server artifact,
publisher, owned session and final-pull hook existed only in the uncommitted
checkout at completion of the initial local pass. This alignment preserves that
work; initial local evidence does not establish exact-head CI or production state.

Offline tests use temporary synthetic fixtures and fake SSH/Kamal/Docker/HTTP
boundaries; they do not contact the VPS or execute a production image.

## Focused verification

- `bin/release check`, ShellCheck for `bin/release`/`lib/release_image.sh`, Ruby
  syntax and `git diff --check` passed. The local check opened no production SSH.
- `bin/rubocop test/scripts/release_test.rb`: one file, no offenses. The default
  cache directory was unavailable in the sandbox; lint continued without cache.
- Local Markdown targets passed for the five changed/new Markdown files. The
  shared agreement matches TwoRiversReporter byte-for-byte, SHA-256
  `aab8c3077ba38ff0cfd947c404e040c2e06cc93e6211fe52faf52f0d2728c95f`.
- A bounded negative control removed only `release_kamal`'s session guard from
  a disposable copy of the release script. The lost-master test failed as
  expected: one test/one assertion/one failure, exposing an extra simulated
  `kamal app details` invocation. The working guard was untouched and the copied
  files were removed. This is offline fault evidence, not production injection.

- Normal Rails runner, with inherited primary/cache/queue database URLs removed:
  `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/scripts/release_test.rb`:
  **14 tests, 165 assertions, no failures/errors/skips**. This includes normal
  deployment/final-pull refusals, internal and diagnostic config routing, quoted
  argument preservation, configuration override refusal, master loss, session
  retention and cleanup. The working lost-master test passes after the isolated
  negative control; no working source restoration was needed.

Full application/browser suites, actual-image builds, exact-head CI, publication,
production SSH and deployment were not run in this alignment pass. There was no
commit, push, merge, host permission change, member-data copy, email or paid call.

## Authorized commit and CI phase

Andre subsequently authorized committing and pushing the complete reviewed release
path and checking CI. Use a review branch and normal pull request under the
repository's existing protections; merge remains a separate action. The shared
agreement remains identical in all three repositories.

Relative to parent `846cacfb77bc7590766274c46a7fbbe12ccfc096`, the complete change
affects operator/build/publication/smoke tooling, tests and documentation. The
Dockerfile change is comment-only. Application code, dependencies, database
schemas/settings, migrations, entrypoint, Puma and queue configuration are
unchanged. The added synthetic startup checker is invoked only by image
verification, not ordinary startup. The coordinator therefore determined that
this alignment needs no image publication or production replacement. No production
window will be opened for this task. Exact pushed commit, PR and CI outcomes are
reported separately after execution rather than inferred from local checks.

## Deferred work and operator checks

- Publication verifies archive configuration/image ID, then registry labels and
  platform. It does not compare the published config digest with the tested image
  ID. A synthetic audit probe changed registry configuration while retaining
  labels; publication accepted it. The expected-refusal probe failed with one
  test/one assertion. No real registry was used. Fixing this binding is outside
  this alignment pass.
- `release_verify` checks the web container name for HEAD, both cohost web IDs,
  this app's database ID and public HTTP responses. The actual running image
  identity, other cohost database/proxy identities, worker health, queue depth,
  migrations and affected workflows still need operator verification.
- Successful normal application CI at the exact release SHA is an operator gate;
  the publisher enforces only the image workflow's successful exact SHA. Capacity
  assessment, serialization across apps and the five-minute failure cooldown are
  operator rules, not a host-wide lock or timer.
- There is no guarded rollback command. The final-pull hook requires the current
  reviewed HEAD, so a bare Kamal rollback to an older version is not a supported
  shortcut. Plan reviewed rollback image evidence and schema compatibility before
  replacement; do not bypass the hook or rewind production data automatically.
- Backup and restore requirements remain in the deployment guide. This audit
  establishes no current backup execution, restore rehearsal or retention state.
- `bin/sync_prod_db` still calls bare SSH and cannot select the session's private
  socket. Align that transport separately before use under the shared agreement;
  production member-data copying retains its explicit authorization requirement.
- Publication removes its temporary local registry credentials. The release
  wrapper removes its owned master/config on exit; it does not claim to erase
  pre-existing or remote registry credentials. Do not globally prune shared
  Docker resources or log out a shared account as routine cleanup.

Historical mobile handoffs retain their dated commands with existing supersession
notices. Current operations follow the shared agreement and deployment guide.
Sandbox ownership errors require read-only host verification; no system-file
ownership or Docker permissions were changed here.
