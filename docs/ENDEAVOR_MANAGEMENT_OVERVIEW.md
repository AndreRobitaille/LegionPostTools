# Endeavor management overview

A read-only officer overview at Administration / Officer tools → Manage Endeavors shows
whether continuing Post work has current generated history and where an officer may need
to act. Detailed refresh, guidance, withdrawal, and diagnostics stay on each AI history
page. Opening or filtering this overview never starts AI calls.

Use the existing `manage_agendas` capability for the page and all entry links. Scope rows
to the installation organization. Members retain their existing reading experience.

## Visual direction

Follow The 1919: navy #0B2238, paper #F4EFDE, card #FBF7EC, gold #D6B46A,
attention red #8C1622. System sans for working text, existing tracked section labels;
reserve Georgia for original documents. Body and interactive text stay at least 16px.

Choose a spacious ledger over a grid of dashboard cards: each row joins the Endeavor name,
plain processing status, latest published update, and links to manage/read it. The status
column is the signature organizing device; it describes AI history, never project progress.
Rows stack on phones. A wrapping filter strip has counts and a clear current selection.
Avoid charts and duplicate editing forms. Keep active/completed lifecycle separate.

Status precedence: withdrawn; queued/running; latest run failed; no available minutes;
not generated; outdated; current. Outdated compares the latest edition manifest against
current revisions, identity/catalog, guidance generation, and model/prompt configuration,
matching processing inputs. A failure can coexist with an older published edition; retain
its date and explain that the latest attempt failed. Superseded attempts are not failures.
Filters: all, needs attention (failed/outdated/not generated), processing, failed, outdated,
not generated, withdrawn. No-minutes rows should explain the prerequisite without calling
for a pointless rerun. Include completed Endeavors so their history remains manageable.

Verify status precedence and stale-input detection, organization scope, member denial and
hidden links, officer access, empty/filter states, desktop/390px readability, and focus.

## Local verification

Checked with six local Endeavors at 1440px and 390px: rows remain readable without
horizontal overflow; filters wrap, keyboard activation selects the attention view, and
Manage history opens the intended Endeavor with a return link. An ordinary member's direct
request redirects away. Three current and three not-generated histories render correctly;
AI processing stays disabled and no paid generation was invoked.

Controller, workspace, and history-service regression tests: 41 tests, 288 assertions,
no failures/errors/skips. Focused RuboCop, Tailwind build, and whitespace checks pass.
