# Off-server image tooling: local verification

November 1, 2026. Implementation is uncommitted. This is a local verification
record, not an image publication or production release record.

The design follows the `wipost165` workflow/archive publisher and owned release
session, adapted to this application's three PostgreSQL databases, SQL primary
schema, Ruby cache/queue schemas, compiled assets, PDF/image processing, two Puma
workers, storage and Solid Queue. `config/deploy.yml`, database/Puma/queue settings
and the production entrypoint are unchanged. Service, image repository, databases,
storage and accessory identities remain intact.

## Actual local checks

- Ordinary suite: `RAILS_ENV=test PARALLEL_WORKERS=2 bin/rails test` with inherited
  database URLs removed: **1,663 tests, 17,470 assertions, no failures/errors/skips**.
- Browser suite: `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test:system` with
  inherited database URLs removed and installed Chromium/chromedriver selected:
  **115 tests, 6,152 assertions, no failures/errors/skips**, on synthetic test data.
- Full RuboCop: **695 files, no offenses**. Focused lint also passed after later
  shell-session/test refinements.
- Brakeman **8.1.0**: **zero errors, zero security warnings**. Its first attempt
  could not write the default gem-spec cache; rerunning with
  `GEM_SPEC_CACHE=tmp/gem-spec-cache` passed, including the latest-version check.
- Bundler Audit: **no vulnerabilities**, using advisory database commit
  `79c0e052ade15d29d3ecc1e8d4fa59c337a86383` in `tmp/legion-ruby-advisory-db`.
- ShellCheck, `bash -n` through `bin/release check`, changed Markdown reference
  checks and `git diff --check` passed. `bin/release check` opened no SSH connection.

The ordinary suite ran before the browser suite. The final script checks below
cover subsequent release-shell refinements; application runtime code did not change.

## Offline workflow evidence

`test/scripts/production_image_test.rb` runs the real builder orchestrator,
publisher, archive verifier and resource-limit refusal against simulated external
commands and synthetic tar/configuration bytes. Runtime/startup smokes in the
orchestrator test are fixtures, **not execution of a Docker image**. Publication
tests never contact GitHub/GHCR and explicitly select the fake crane executable.

`test/scripts/release_test.rb` runs the real release entry point, shared helper and
pre-deploy hook against simulated SSH/Kamal/Docker/HTTP boundaries. It checks one
outer master, no reconnect after loss, retention after failure, final cleanup,
digest/revision/service/platform refusals, clean/pushed source, failed pulls,
changed final-pull metadata, Kamal version override, protected cohost identities
and subsequent live-revision/HTTP verification. All container replacement markers
are **simulated**, and the production URLs in command logs are fake HTTP calls.

The inherited-shell-options refusal test exposed a real local defect: exported
`SHELLOPTS` could terminate the interactive shell after a failed release. The owned
session now clears imported shell options and explicitly disables errexit in its
interactive shell; deployment commands retain their own strict failure handling.
The final test proves a missing/invalid digest leaves the session open without
pulling or replacing anything.

Final standalone results, all with zero failures/errors/skips:

| Offline test file | Tests | Assertions |
| --- | ---: | ---: |
| `test/scripts/production_image_test.rb` | 12 | 154 |
| `test/scripts/release_test.rb` | 11 | 125 |
| `test/scripts/production_startup_smoke_test.rb` | 3 | 11 |

The final smoke-checker component tests were added after the ordinary suite. They
execute the real Ruby checker with a simulated Rails/cache/storage boundary and
later worker commit. Source review identified the need to bypass the runner's
query cache while polling a deletion committed on another connection. A queued job that never
finishes and non-synthetic database names are refused. These tests do not execute
Rails, PostgreSQL, Solid Queue or Docker. Actual-image execution remains outstanding.

### Representative defect detection

This command deliberately removed only the final-pull guard **inside each test's
temporary fixture**, leaving the working hook untouched:

```bash
bundle exec ruby -Itest -r./test/scripts/release_test.rb - \
  --name test_changed_image_after_final_pull_cannot_replace_containers <<'RUBY'
ReleaseTest.class_eval do
  alias_method :setup_with_final_guard, :setup
  def setup
    setup_with_final_guard
    hook = "#{@directory}/.kamal/hooks/pre-deploy"
    File.write(hook, File.read(hook).sub("exec bin/release verify-image", "exit 0"))
  end
end
RUBY
```

Expected negative control: **1 test, 2 assertions, 1 failure**, because a changed
final-pull digest incorrectly reached the simulated `BOOT` marker. The unmodified
test rejects that replacement and passes in the workflow suite. This establishes
representative guard regression detection, not production fault injection.

A second negative control removed `uncached` only from a disposable copy of the
Ruby smoke checker. Its later-worker-commit test failed as expected (**1 test,
1 assertion, 1 failure**) because the simulated stale query cache hid the deletion.
The working checker was untouched and its three component tests passed.

## Evidence not obtained

The local Docker Unix socket rejected access, including host access; passwordless
sudo was unavailable. No host permissions were changed. Consequently the new
actual-image smokes/build/export were **not executed against a real Docker daemon**.
A successful GitHub Actions build for the committed revision remains necessary
before any maintainer publication. No GitHub workflow was dispatched here.

There was no commit, push, merge, image publication, production connection,
deployment, member-data copy, real email or paid AI call. No CI or production
success is claimed. The older October 31 build measurements remain separately
dated historical evidence in `docs/PRODUCTION_IMAGE_BUILD.md`.
