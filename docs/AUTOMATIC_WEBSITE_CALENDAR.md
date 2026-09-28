# Automatic website calendar

Implementation design, September 28, 2026.

## Product behavior

CalendarEvents remain standalone attendance events with an optional Endeavor link.
Meetings remain first-class records with their existing agenda and official-record
protections. Both can supply a public schedule notice without exposing documents.

A publisher chooses Post-wide defaults from explicitly stored calendar categories.
Suggested defaults are member meetings and public events. Name-based calendar color
classification is never publication authority. Unspecified types have no public default.
Each occurrence has Type default / Show / Hide, independent of who may attend.
Calendar managers and meeting managers maintain their respective listings as part of
normal saves under this standing policy. Defaults require publish_public_content.

Only the title (optionally overridden for the website), schedule, place, attendance,
cancellation and dedicated website description are public. Never copy private event
descriptions, Endeavor history, agendas, minutes, transcripts, actors, or audit metadata.
The attendance label is included in public description text for existing consumers.
Source changes update listings immediately; cancellations remain visible as notices.
Hide and deletion remove detail access as well as collection membership.

## Transition and contract

The migration does not activate automatic listings. Existing installations continue
serving legacy event snapshots until a publisher reviews and activates the defaults.
The preview includes all existing candidate records and their effective visibility,
with a signed, expiring token tied to source revisions and the policy revision.
Activation is one-way: returning to old snapshots could revive withdrawn content.
Subsequent default changes use the same preview and stale-review protection.

Existing publication identities and audit history are retained. Published event copy
is seeded into dedicated website fields and withdrawn records start with Hide.
Unreviewed existing categories are not inferred or backfilled from names/visibility.
After activation, legacy event publication writes are rejected in favor of calendar
editing; introduction drafting, portraits, consent and publication remain unchanged.

The authenticated /public/v1 event payload stays compatible, including category
public_event, opaque IDs, date overlap, cancellation, and the 300-second cache limit.
An additive attendance value distinguishes public listing from attendance rights.
Policy and source writes serialize with feed reads through the existing Post advisory
lock. A separate append-only audit records policy and listing edits, including actor
and delegated agent provenance. No new grants are created.

## Visual direction

Use The 1919 working-screen system: navy #0A2240 actions, gold #C6A15B confirmation,
ivory #FCFAF1, ink #1b222b and restrained red #8C1622 for errors. System sans for
all controls; serif remains reserved for official documents. Body/controls 16px,
secondary text 14px, labels at least 13px. Existing bounded columns, section headers,
form fields and 900/560px responsive breakpoints apply.

Event and meeting forms group attendance, website visibility, website title and public
description beside the existing schedule. The Public website workspace links to
Calendar defaults. Its defining element is a plain list pairing each actual occurrence
with its proposed Shown/Hidden state. This makes the activation consequence visible
without a second per-event publication workflow. Lists wrap vertically on narrow screens.

## Verification

Cover explicit categories versus title inference, defaults and overrides, attendance,
meeting field isolation, legacy transition/IDs, live updates/cancellations, withdrawal,
date overlap, organization scope, authority, signed stale previews, audit provenance,
HTML/API parity and existing consumer validation. Run focused and full Rails tests,
lint/security checks and desktop/narrow browser checks with synthetic test data.
Production activation, content edits, commit, push and deployment are not part of this
local implementation authorization.

Local verification completed:

- Rails suite: 1,034 tests, 7,489 assertions, no failures/errors/skips.
- Browser suite: 37 tests, 421 assertions, no failures/errors/skips; the new workflow
  also passed a final desktop/390px layout check after spacing refinements.
- RuboCop: 464 files, no offenses. Brakeman: zero warnings/errors. Dependency audit:
  no vulnerabilities. Whitespace/diff checks passed.
- The current wipost165 consumer validator accepted synthetic timed/cancelled,
  all-day and membership-meeting collection/detail notices without database writes.
- Test and development schemas migrated locally. Automatic listings remain inactive
  in development until reviewed activation; no production operations were performed.
