# Off-server production images

Local implementation plan, November 1, 2026. This document authorizes no release.

Builds move to disposable GitHub-hosted Linux amd64 runners. The runner receives
source, not production keys, data, SSH access, or registry write permission. A fresh
1,536 MiB BuildKit builder retains serial Bundler and Bootsnap compilation. The
final image must pass the existing offline PDF/libvips/bundle smoke and a real
entrypoint smoke on an internal Docker network with disposable PostgreSQL 17.
The latter checks all three databases, migrations, compiled asset delivery, two
Puma workers, a Solid Queue heartbeat and a completed synthetic queued job.

Successful push/manual runs export the tested image, exact revision, image
configuration and smoke evidence, with checksums. PR runs test but do not offer a
release artifact. CI never logs in to a registry, publishes, or deploys.
`bin/publish-image RUN_ID` is a separate, explicit maintainer action. It requires a
clean checkout, a successful matching workflow run and exact source SHA; checks
the archive and its configuration before publication; uses temporary registry
credentials; and reports the verified registry manifest digest.

`bin/release check` becomes local-only. An explicitly authorized production
operation uses `bin/release session`, which owns one temporary OpenSSH master and
keeps it until the operator exits, including after failed commands. Commands and
Kamal's proxy use that socket with reconnect disabled. No standalone deploy or
automatic reconnect is available. After connection failure, stop; wait five
minutes before one explicitly chosen replacement attempt.

Inside the session, `release_deploy` requires a clean, exactly pushed revision and
a sha256 manifest digest. It pulls and validates the digest, revision, service and
linux/amd64 platform, then runs Kamal with `--skip-push`. The executable pre-deploy
hook repeats validation after Kamal's final pull, checks `KAMAL_VERSION`, and
refuses execution outside the owned session. Missing evidence never falls back
to a build. Service, registry, PostgreSQL, storage, proxy and public hostnames stay
unchanged. Verification checks the running revision, protected cohost containers,
and all three sites. Production worker health remains an operator check; image
smokes do not establish production job health or upgrade compatibility with every
historical database.

Offline tests exercise the actual command scripts with simulated GitHub, registry,
Docker, SSH and Kamal boundaries. They cover publication, deployment, cleanup,
changed final-pull metadata, lost connections and refusal paths. A controlled
mutation must demonstrate that the final-pull refusal detects a removed guard.
These tests are simulations, separate from actual image execution, GitHub CI and
production verification. No production operation is part of this implementation.

## Shared-host alignment

Use the identical [shared operator agreement](../SHARED_HOST_DEPLOYMENT.md) in all
three repositories, with installation details and remaining operator checks in
this app's deployment guide. Add `release_kamal` to the owned shell: it checks the
existing master, refuses caller-supplied configuration and injects the generated
session configuration. Internal Kamal calls use the same helper, preserving the
explicit reviewed version, digest checks, final-pull hook and `--skip-push`.
The helper never opens or retries an outer SSH connection.

Verify additional diagnostic commands, argument/configuration routing and refusal
after master loss through the normal offline test file. Inject a representative
fault only into a disposable test fixture. Publication config-digest binding,
running-image verification, database-sync transport, shared locking and guarded
rollback remain separate follow-up work; this alignment does not redesign them.

## Startup verification budget

The first actual-image runs exposed an OOM when the extra Rails checker shared
the app's 512 MiB cgroup after two Puma workers and Solid Queue had started.
Keep that app limit, worker count, real entrypoint and 1,536 MiB builder limit.
Run the synthetic database/cache/storage checker in a separate 512 MiB container
using the same image, internal network, synthetic environment and disposable
storage volume. The app's existing queue worker must complete its purge job.
Capture both containers' state and configured limits before cleanup on success
or failure, then remove the owned containers, storage volume and network.
