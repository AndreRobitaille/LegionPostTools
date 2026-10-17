# Members sharing production release — October 17, 2026

The members sharing and sign-in return release is deployed and publicly verified.
Andre explicitly authorized the narrow commit, push, deployment, and read-only
verification after the local implementation handoff. This release did not merge
into master or deploy either co-hosted application.

## Release identity and base

- Release: `43c189b112fb3ecf07eb543d43bb79977d62f104` (SSH-signed commit).
- Pushed branch: `codex/members-sharing-release-20261017`; GitHub's branch SHA was
  verified by the wrapper and again after deployment.
- Repository: `https://github.com/AndreRobitaille/LegionPostTools`.
- Actual previous live revision and release parent:
  `607e995f7654fb220a7996d5fe10caa131acee25`.
- Clean isolated release checkout: `/tmp/legion-members-sharing-release-20261017`.
- Running container:
  `legion_post_165_wi_tools-web-43c189b112fb3ecf07eb543d43bb79977d62f104`.
- Running image:
  `ghcr.io/andrerobitaille/legion-post-165-wi-tools:43c189b112fb3ecf07eb543d43bb79977d62f104`.
- Image digest reported by Docker and the build/push:
  `sha256:7a4919ea95f3b60e5673ad395feb8cf18449070a2e182c334993699822fd287f`.
- Implementation session: `01a14abb-d1e3-74b3-abf4-daf59ee755e6`.

Live revision discovery happened inside the retained SSH session before the release
base was chosen. It matched the local implementation base exactly, so no rebase,
feature transplant, or repeat application test run was necessary. All 61 reviewed
files were copied with matching SHA256 hashes into the isolated checkout and were
the only staged/committed files. Deployment YAML comparison confirmed that only
the five public `MEMBERS_SITE_*` settings were added; existing mobile, database,
email, WebAuthn, worker, and other deployment settings were preserved. There are no
schema changes in this release. `BUDDY_CHECK_ACTIVATE_EMAIL` was explicitly unset.

## Guarded release and connection lifecycle

The host-level SSH configuration was inspected outside the restricted sandbox.
There was no pre-existing Post 165 control socket. `bin/release check` created the
operation-owned master, PID `219446`, at **2026-10-17 16:58:32 UTC** and the
configured control path:
`/home/andre/.ssh/controlmasters/legion-post-tools-prod`.

The following used `RELEASE_KEEP_SSH_MASTER=true`:

1. `bin/release check` from the implementation checkout: transport preflight passed.
2. `bin/release push-deploy` from the clean isolated release checkout: exact pushed
   SHA verified, remote build/push and deployment passed, and running SHA/public
   health verified. Kamal reported 65.2 seconds for the deployment.

The master remained PID `219446` at every liveness check, including deployment and
final container verification. Net::SSH used the wrapper's generated `ssh -W` proxy;
Docker/buildx used the same configured master. After initial creation, an ephemeral
SSH launcher under `/tmp/members-sharing-release-bin` disabled direct fallback via
`ProxyCommand=false` and refused replacement master creation. It did not alter
repository release code or host SSH configuration. No replacement, reconnect,
parallel outer SSH connection, activation, or regrant was attempted. Public HTTPS
verification used ordinary anonymous requests and did not create sign-ins.

After every production check completed, PID `219446` was verified once more and
closed with a single `ssh -O exit` at **2026-10-17 17:03:45 UTC**. A local
control-socket check failed as expected and the socket was absent. No owned tunnel
remains open. The same master covered the entire 5-minute-13-second operation.

## Production observations

Verification completed by **2026-10-17 17:02:52 UTC**, before closing the master.
The wrapper verified `/up`, `/session/new`, and the Two Rivers root at HTTP 200.
The additional public verifier checked 29 responses without credentials or cookies:

| Request | Observed result |
| --- | --- |
| `/session/new` | 200; title/application name `Post 165 Members`; approved description, complete generic OG/Twitter fields, configured HTTPS root/image URLs, correct icon links |
| `/session/code?token=synthetic-preview` | 200; identical generic metadata; synthetic query absent from metadata |
| `/session/magic_link?token=synthetic-preview` | GET and HEAD 200; generic confirmation metadata; no valid credential supplied or consumed |
| `/`, `/meetings`, `/people`, `/dated_agendas/0`, `/calendar/print` | 302 to `https://members.wipost165.org/session/new`, including requests with a preview-client user agent |
| `/api` | 401 as plain text without JSON Accept; 401 as JSON with `Accept: application/json` |
| `/members-sharing-missing-page` | 404 with noindex header and HTML robots meta |
| `/404.html`, `/406-unsupported-browser.html` | 200 static error documents with noindex header and HTML robots meta |
| `/robots.txt` | 200; `Allow: /`, no blanket crawl block and no sitemap |
| `/up` | 200 |

Every members response above and every asset response below returned
`X-Robots-Tag: noindex, nofollow`. Entry/error HTML retained the matching robots meta.
The entry metadata matched all approved configured values, including image MIME,
1200 × 630 dimensions, alt text, and token/query-free canonical preview URL.
Requests used only synthetic preview query values, never actual sign-in credentials.

All ten assets returned 200 and matched the release files byte for byte. The Post
165 JPEG is also byte-identical to the approved package. SVGs remain outlined and
self-contained. Dimensions and served media types were inspected from the actual
public response bytes:

| Members path | Media type | Dimensions | SHA256 |
| --- | --- | --- | --- |
| `/members/post165/members-og.jpg` | `image/jpeg` | 1200x630 | `281ade95692cddc5a6b8874b1c6a7489afdf247434e200ef2309702eb7d2a274` |
| `/members/members-og.jpg` | `image/jpeg` | 1200x630 | `906252b647ec2f9a3a2f7d2f9e18aa93655c198a5006e11be464a95f2b1f8356` |
| `/favicon-96.png` | `image/png` | 96x96 | `26a944b923e8a51b616718f292ee3998d67aac66794c99d5dd93abdb3b7e7cf3` |
| `/apple-touch-icon.png` | `image/png` | 180x180 | `a4687988c6d47dc92088de4a36b0449fdfd0cffe4ccd30685eac9e923c97515e` |
| `/members/app-icon-192.png` | `image/png` | 192x192 | `45aaf77ccfc3a2d6f5127d46797414be750c923820e362c97600e5a4ea003d1f` |
| `/members/app-icon-512.png` | `image/png` | 512x512 | `7a2598dae7a1ed0ee0445026e000faaa54267d3d8b14ed2155bc22cfb940768a` |
| `/favicon.ico` | `image/vnd.microsoft.icon` | 16x16 32x32 48x48 | `5b8a3039531f08023c996a1ff77d3987ed05182a9d44059cd2eb18772e573406` |
| `/favicon.svg` | `image/svg+xml` | 512x512 | `c55d9490cc5fbf823812335757ae5ad3ce73c3204e10cc6cd9cac8a04c95393f` |
| `/icon.png` | `image/png` | 96x96 | `26a944b923e8a51b616718f292ee3998d67aac66794c99d5dd93abdb3b7e7cf3` |
| `/icon.svg` | `image/svg+xml` | 512x512 | `c55d9490cc5fbf823812335757ae5ad3ce73c3204e10cc6cd9cac8a04c95393f` |

### Co-hosted services

- `https://wipost165.org/` and `https://www.wipost165.org/`: 200; title remains
  `American Legion Post 165, Two Rivers`; no members `X-Robots-Tag` was added.
- Public Post container/image revision remains
  `76f4f5cba5c7785a192ad7d3e22bf6ac448af7d9`; container ID remains
  `af3f044a1621d1fba2128a887f579465b39b3267def60f4f5f2e0652367ac193`.
- `https://tworiversmatters.com/`: 200; title remains
  `Two Rivers Matters: Two Rivers, WI City Hall in Plain English`; indexing header
  remains unchanged.
- Two Rivers container/image revision remains
  `37383fc06613731e6fed7b6ec9039c1eef3325cc`; container ID remains
  `326c06aaf63a5ab746bf246e1845e49fdc1efca11832000ab21efcc6221015ee`.
- Both database container IDs and the shared proxy container ID also remained
  unchanged. No database content was queried for these comparisons.

The public HTML bodies had differing response hashes; no page-byte identity claim
is made. Service identity, response status, title, and indexing-header comparisons
passed, and the exact pre-existing co-hosted containers/images remained running.

## Rollback identity

Previous live image:
`ghcr.io/andrerobitaille/legion-post-165-wi-tools:607e995f7654fb220a7996d5fe10caa131acee25`.
Docker image identity:
`sha256:117fdf70d1897bc8e434e3ff5f1282c846fc11a1a1e98d0402a892e26dc6a9c0`.
The previous web container was retained in the exited state after deployment.
No rollback was needed or performed. This is a code/configuration release without
new migrations; any future rollback should target that exact revision using the
project's guarded release transport, rather than assuming master is current.

## Evidence, failures, and limits

[The local implementation handoff](MEMBERS_SITE_SHARING_2026-10-17.md) records
108 passing browser tests and the 1,510-test ordinary suite with zero assertion
failures and one independently reproduced pre-existing Buddy Check date error at
`test/services/buddy_checks/evidence_test.rb:140`. That unrelated behavior was not
changed. Existing lint/security/asset checks were not rerun as a release ceremony.
Release-specific checks covered the live base, exact staged file hashes, unchanged
configuration, clean checkout, pushed/running SHA, public delivery, and preservation.

The first HTTP verifier assumed JSON for `/api` without requesting it; production
correctly returned 401 plain text. The verifier was corrected to check both content
negotiations and then completed successfully. No application fix or redeployment
was needed. Release-wide whitespace review also found the upstream OFL notice's
single trailing space on line 21; its supplied bytes were intentionally preserved.
All other release paths passed the whitespace check. No transport/deploy failure
occurred. The early local review commands accidentally ran from `/tmp` rather than
the clone; they were corrected before committing and did not affect production.

Production evidence is anonymous public HTTP and container metadata. Successful
email-code/magic-link/passkey return, permission changes, token replay boundaries,
OAuth consent/PKCE, and protected PDF/Active Storage delivery remain the synthetic
local evidence already recorded. No production sign-in, private member query/data
copy, member-record change, grant/activation, paid application AI request, external
message, unrelated merge, or public-site deployment was performed. Live iMessage
previews and real-device passkey prompts were not verified.

At release completion, original master remained at `607e995f7654fb220a7996d5fe10caa131acee25`. All original
implementation and unrelated file bytes, dirty/untracked states, and the empty index
were preserved; the signed release commit lives on the pushed isolated `codex/`
branch. The five named mobile handoffs remain untouched. This post-release record
is the only additional local task file. The release checkout remains clean.

Raw non-secret evidence is retained locally under `/tmp/members-sharing-*`, including
`release-preflight.log`, `push-deploy.log`, `production-before.txt`,
`production-after.txt`, `running-rollback.txt`,
`production-http-verification.json`, and `public-verification.log`.

## Subsequent Git integration

The owner subsequently authorized integrating this session's changes into `master`
and retiring its release branch. The release, editable asset package, and this
record are retained in master; this Git cleanup does not run Kamal or change the
deployed revision. The existing date-dependent Buddy Check test uses current-date
event instants in the integration commit, preserving its newer-event-first /
older-event-later assertion without changing application behavior.

The five unrelated mobile handoff edits are preserved separately at the owner's
request so the primary checkout can be clean. Their detached, locked local checkout
is `/home/andre/Development/LegionPostTools-mobile-handoffs-preserved-20261017`,
based on `607e995f7654fb220a7996d5fe10caa131acee25`. `PRESERVATION.json` in that
checkout records the original paths, tracked/untracked state, and verified SHA256
hashes. The five edits are not committed, pushed, or part of this sharing release.
