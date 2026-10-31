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

`Profile production image` runs this comparison on an isolated GitHub Actions runner
without production secrets or an SSH connection. Its output is evidence for the
measured revision, BuildKit version, architecture, and cache state. A cold CI build
does not establish the shared VPS's future peak or available application headroom.
An OOM within the isolated builder is a failed measurement, not permission to raise
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
