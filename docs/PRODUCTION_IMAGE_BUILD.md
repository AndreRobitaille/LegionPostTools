# Production image measurement and dependency scope

The production image must boot Rails, serve compiled assets, render official-record
and calendar PDFs with Chromium, process portraits with libvips, and prepare the
PostgreSQL databases. Browser-test drivers, debuggers, linters, and the workstation's
Kamal client are not application runtime dependencies. Keep their locked versions
available for development and CI, but exclude both the development and test groups
from the production bundle. Keep Chromium, fonts, libvips, and PostgreSQL clients.

The October 31 release investigation measures builds away from the shared production
VPS. The existing 1,536 MiB builder limit is a ceiling, not an observed minimum.
Use a fresh Docker-container BuildKit builder at that limit, with swap disabled,
for each revision so the comparison includes cold native gem installation,
Bootsnap, assets, and image export. Preserve `bundle install --jobs 1` and serial
Bootsnap compilation. Read the builder's cgroup v2 `memory.peak`, `memory.events`,
and sampled anonymous/file memory; do not substitute the build client's RSS or
sum forked Ruby process RSS. Record the image size and installed gem names too.

`Profile production image` runs on an isolated GitHub Actions runner
without production secrets or an SSH connection. Its output is evidence for the
measured revision, BuildKit version, architecture, and cache state. A cold CI build
does not establish the shared VPS's future peak or available application headroom.
Supply an optional baseline commit for a cold comparison; omit it to measure only
the selected revision. An OOM within the isolated builder is a failed measurement, not permission to raise
the production cap. The runtime smoke uses synthetic HTML/image data and performs
no database access, email delivery, or AI generation.

After measurement, inspect live resources through the release wrapper's one retained
SSH master. Follow the shared-host safeguards in [DEPLOYMENT.md](DEPLOYMENT.md).
Do not start an on-server build unless it leaves application headroom. If the measured
build cannot fit, use a verified image built away from production or report the
remaining release blocker; do not change application capacity or buy RAM implicitly.

This change does not alter official records, permissions, data, or worker settings.
Validation must establish that excluded gems are absent, workstation Kamal still
loads, Rails boots in the final production image, and Chromium PDF rendering,
libvips processing, PostgreSQL tools, and compiled assets remain available. The
existing calendar and Buddy Check regression workflows remain required CI evidence
for the merged fixes.

The isolated startup smoke uses disposable PostgreSQL databases and a Docker network
with no external access. It runs the real entrypoint, Thruster, two Puma workers,
and Solid Queue within a 512 MiB app limit; checks health/sign-in and a fresh queue
worker heartbeat; and records its startup peak/events. This is startup evidence,
not a guarantee about steady-state member traffic or background jobs.

## Deploy an image built away from the VPS

After the source revision passes CI, run the manual workflow at that exact ref with
`export_image=true`. It smoke-tests the final image before exporting a private,
short-lived Docker archive artifact with its checksum. No production keys, database
contents, registry credentials, or SSH credentials are supplied to the runner.

On the maintainer workstation, download the artifact, verify `SHA256SUMS`, and publish
the archive to the existing private image repository at the full source SHA. Docker
or Google's `crane push` can publish it; crane also works without a local Docker
daemon. Use existing local registry authentication, never upload the maintainer's
GitHub token to the CI runner. Record the registry manifest digest and confirm its
revision and service labels before release.

Set `RELEASE_IMAGE_DIGEST=sha256:<verified manifest digest>` on `bin/release
push-deploy`. The wrapper requires a clean, exactly pushed HEAD, pulls the image,
and rejects a mismatched digest, source revision, service, or architecture before
Kamal can replace the app. It then uses Kamal's `--skip-push` option, so no build
runs on the VPS. Omitting the digest keeps the existing remote-build behavior and
its full memory safeguards. The digest is not a Git commit or archive checksum.

Keep `RELEASE_KEEP_SSH_MASTER=true` through preflight, resource inspection, deploy,
and final verification. Production commands and Kamal's proxy fail closed if that
master disappears; they must not silently open another outer connection. Optional
`RELEASE_SSH_CONFIG` selects a maintainer SSH config (the existing Post 165 path is
the default). Check all three sites and worker health, and close the master at the
end. An off-server build still needs room for image extraction and the temporary
overlap of old/new app containers; inspect resources before deploying.
