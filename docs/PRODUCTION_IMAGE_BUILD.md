# Production image builds and evidence

Images must boot Rails, serve compiled assets, render PDFs with Chromium, process
portraits with libvips and prepare PostgreSQL. Exclude development/test gems while
retaining Chromium/fonts, libvips and PostgreSQL clients. Preserve the primary SQL
schema's official-record triggers and the cache/queue Ruby schema formats.

## Isolated build contract

**Build production image** runs on a fresh GitHub-hosted Linux amd64 runner for
master pushes, relevant PRs or explicit manual dispatches. It receives no production
secrets/data, registry write permission or SSH access. The build scripts refuse
workstations, self-hosted runners, wrong architectures and Docker host/context
overrides; Docker commands explicitly select the runner's local Unix socket.
Source comes from `git archive` of the exact revision, filtered by `.dockerignore`.

`script/build_production_image REVISION OUTPUT_DIR` creates a fresh pinned BuildKit
v0.32.2 container with memory and memory-plus-swap limits of 1,536 MiB. Preserve
`bundle install --jobs 1` and Bootsnap `-j 1`. Cold profiling captures kernel cgroup
peak/events, sampled anon/file memory, installed gems, image size and pg_dump
version. Do not substitute client RSS for builder peak or raise limits after OOM.
`script/profile_production_image REVISION LABEL OUTPUT_DIR` remains available for
isolated cold comparisons; profiling alone does not produce a release artifact.

The actual final image runs synthetic checks without production keys:

- Rails production boot, physical absence of workstation/test gems, compiled
  assets, Chromium PDF rendering and libvips on `--network none`.
- Real `bin/docker-entrypoint` and `db:prepare`, Thruster, two Puma workers and
  Solid Queue on an internal-only Docker network with disposable PostgreSQL 17.
- Fresh primary, cache and queue schemas with no pending migrations, health and
  sign-in pages, actual compiled stylesheet delivery, fresh worker heartbeat,
  Solid Cache write/read, and a synthetic Active Storage purge completed by the
  asynchronous worker. Containers and their disposable volumes are removed.

No email or AI generation is requested. No production keys, databases, storage
volumes or member rows enter this process. An internal network also prevents
smoke jobs reaching external providers. These are fresh-database/startup checks,
not every historical migration upgrade, production load or delivery acceptance.

Only after both smokes pass does the script save that same tested image, then
verify the exported configuration. The release artifact contains `image.tar.gz`,
`revision.txt`, `evidence.json` (config/image ID, identity, platform and passed
smokes), and `SHA256SUMS` covering all three. Check logs are retained seven days;
push/manual image artifacts three days. PR runs upload check evidence only. CI
contains no registry login, image push or deployment step.

## Manual publication and deployment

Follow [DEPLOYMENT.md](DEPLOYMENT.md#build-publish-deploy). On a clean checkout of
the reviewed full revision, `bin/publish-image RUN_ID` checks a successful matching
push/manual workflow, downloads its exact artifact, verifies the required
checksums and archive configuration/image ID, and refuses missing smoke evidence.
It decompresses the outer gzip before `crane push`, uses temporary credentials,
publishes only the full-SHA tag in the unchanged GHCR repository, verifies the
published configuration and prints the registry manifest digest. It refuses CI.

Publication does not deploy. An authorized deployment requires that digest inside
one owned `bin/release session`. The wrapper and final-pull hook reject wrong or
missing digest/revision/service/architecture evidence, always use `--skip-push`,
and stop if the tunnel is lost. There is no build fallback. The pre-build hook
refuses implicit Kamal builds. Check host headroom and all three sites; close the
master only after final verification. A missing/expired artifact requires a new
successful image workflow for the same source revision, never a server build.

## Verification boundaries

`test/scripts/production_image_test.rb` and `test/scripts/release_test.rb` exercise
real command scripts against simulated Actions/registry/Docker/SSH/Kamal
boundaries and synthetic archives. They establish offline publication, refusal,
cleanup and deployment behavior; they do not establish a built image, a successful
GitHub run or any production result. The
[local verification record](deployment/2026-11-01-off-server-image-build-verification.md)
lists actual local checks and representative defect detection separately.

## October 31 cold-build comparison

[Run 41253729492](https://github.com/AndreRobitaille/LegionPostTools/actions/runs/41253729492)
used two fresh BuildKit v0.32.2 builders on an amd64 GitHub runner with Docker
28.0.4. Both had memory and memory-plus-swap limits of 1,610,612,736 bytes, no
imported build cache, and the same Ruby 4.0.7 slim base digest
`sha256:6c6b7b8c7d750604178aa60c2fa436890cd17c5695bdbd3213db2e4efbf98eb9`.

| Observation | Baseline `2cb6a64f` | Trimmed `28014586` |
| --- | ---: | ---: |
| Builder cgroup peak, MiB | 1,465.7 | 1,477.0 |
| Largest sampled anonymous memory, MiB | 123.0 | 104.5 |
| Largest sampled file memory, MiB | 1,283.1 | 1,325.8 |
| Uncompressed final image, MiB | 1,203.0 | 1,116.8 |
| Installed gems reported by Bundler | 134 | 99 |
| Builder OOM / OOM kills | 0 / 0 | 0 / 0 |

The image is 86.2 MiB (7.2%) smaller. The measured builder peak did not fall; most
sampled memory was file cache. This does not establish a 1.5 GiB minimum or measure
the Docker daemon's separate memory. Anonymous/file samples are once per second;
their maxima are not necessarily simultaneous. The cgroup peak is kernel-recorded.
Both builds included gem installation, Bootsnap, assets, and image export.

Bundler's build logs establish the gem counts above. The initial `gems.json` files
enumerated Ruby's default gem path, not the versioned bundle directory, and must
not be used as installed-bundle inventory. The profiler and runtime absence check
now read physical bundle gemspec files explicitly. The trimmed image passed Rails
boot, compiled assets, synthetic PDF rendering (15,798 bytes), libvips, and PostgreSQL
client checks. This comparison did not access production or measure live traffic.

With approximately 800 MiB available at the preceding production inspection, use
the off-server publication path rather than infer that this build fits safely on
the shared host. Reinspect production before replacement; these are dated snapshots.
