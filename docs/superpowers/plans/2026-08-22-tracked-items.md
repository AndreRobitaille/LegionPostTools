# Tracked Items Implementation Plan

**Goal:** Preserve long-lived American Legion business across meetings and let officers
bring it into a dated agenda without weakening agenda snapshot and locking rules.

**Architecture:** Add organization-owned `TrackedItem` records, immutable
`TrackedItemUpdate` history, and an optional tracked-item source on copied
`DatedAgendaItem` records. Keep reading in the authenticated app and reuse
`manage_agendas` for mutations.

**Design:** Follow `docs/superpowers/specs/2026-08-22-tracked-items-design.md` and the
installed frontend-design skill. Reuse “The 1919” tokens, priority vocabulary, readable
type floors, and the continuity-spine signature.

## Tasks

1. Add migrations and model tests for tracked items, append-only updates, prioritization,
   lifecycle provenance, organization boundaries, and agenda snapshot links.
2. Implement the models and associations, including deterministic priority buckets and
   locked lifecycle methods.
3. Add authenticated tracked-item routes and controller tests for member reading and
   `manage_agendas` mutations.
4. Build the index, form, and detail/history views using the documented visual direction;
   activate only the Tracked Items navigation destination introduced by this feature.
5. Add the draft-agenda tracked-business picker, snapshot creation, duplicate protection,
   section destination handling, and locked-agenda tests.
6. Run focused tests, migrate development and test databases, compile CSS, then run the
   full test, RuboCop, Brakeman, and Bundler Audit checks.
7. Run browser QA at desktop and phone widths, critique the rendered design against the
   spec, and fix functional, accessibility, or visual issues found.
8. Apply a final simplification pass, review the complete diff while preserving existing
   unrelated worktree changes, and commit locally without pushing.
