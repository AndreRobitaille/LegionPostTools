# LegionPostTools

Operation tools to run and manage an American Legion post.

## Development

Prerequisites: Ruby 4.0.0 (or the version in `.ruby-version`) and a local PostgreSQL server/role available for Rails development/test databases.

```bash
bundle install
bin/rails db:prepare
bin/dev
```

Open `http://localhost:3000`. On a fresh database, the app shows the first-run setup wizard.

## Authentication

LegionPostTools is passwordless. Users sign in with passkeys or a magic link sent by email. Passwords are intentionally not supported.

## Current Scope

The current implementation provides the Rails foundation, setup wizard, core people/organization model, and passwordless authentication foundation. Structured agendas and minutes are planned next.

Smoke verification:
- Run `bin/rails db:drop db:create db:migrate` or equivalent reset/prepare in the worktree.
- Verify setup can be completed without browser automation if practical using integration tests or Rails runner. If you can safely run a local server and POST setup, do so. Do not leave server running.
- If you use the browser/dev server or `bin/rails runner` to create setup data, the count command runs in `development` by default: `bin/rails runner 'puts [Organization.count, PositionTitle.count, MeetingBody.count, User.count].join(" ")'` (expected `1 11 2 1`).
- If you use controller tests as the non-interactive substitute, run the count check in the same environment, e.g. `RAILS_ENV=test bin/rails runner 'puts [Organization.count, PositionTitle.count, MeetingBody.count, User.count].join(" ")'`, or note that tests verify the setup path separately.
- Run `bin/rails test`.
- Run `git status --short` and ensure only intended README changes before commit.

Because this is a non-interactive agent environment, if manual browser setup is impractical, use existing setup controller tests and/or a Rails runner script to create the same setup data, then run the count check in the matching environment. Report what you did.
