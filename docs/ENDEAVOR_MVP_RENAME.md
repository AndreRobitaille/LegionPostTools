# Endeavor MVP Rename Design

## Objective

Rename the existing Tracked Item feature to Endeavor as one coordinated,
behavior-preserving migration. An Endeavor is the durable identity for one coherent body
of American Legion Post work. This establishes the optional `endeavor_id` seam that a
future structured minutes item can copy deliberately from its agenda item without adding
any minutes behavior now.

`docs/ENDEAVOR_GOVERNANCE.md` defines the product identity and inclusion rules. This
milestone changes names and URLs, not the feature's lifecycle or scope.

## Data Migration

The migration renames existing tables and columns in place:

- `tracked_items` becomes `endeavors`;
- `tracked_item_updates` becomes `endeavor_updates`;
- both foreign-key columns named `tracked_item_id` become `endeavor_id`;
- associated index and check-constraint names adopt Endeavor terminology; and
- Action Text polymorphic types change from `TrackedItem` / `TrackedItemUpdate` to
  `Endeavor` / `EndeavorUpdate`.

The migration is explicitly reversible. It does not copy or recreate business rows, so
IDs, timestamps, optimistic-lock versions, creator/completion provenance, foreign keys,
agenda snapshot links, check constraints, and partial uniqueness remain intact. It does
not update historical `AgentApiExecution#request_path` values.

The original creation migration stays unchanged. A fresh database runs that historical
migration and then the rename, while an existing database renames its populated objects.

## Application Contract

There is one live domain model after migration: `Endeavor` with append-only
`EndeavorUpdate` records. HTML routes, private API routes and payload fields, associations,
helpers, views, and current tests use Endeavor terminology atomically. No compatibility
alias is needed because the private API is discovered through the generated live
handbook, and inspection found no external route consumer in the repository.

Behavior remains unchanged:

- signed-in members can read Endeavors;
- `manage_agendas` controls creation and mutation;
- priority, usual meeting body, completion/reopen provenance, and optimistic locking stay
  intact;
- updates remain append-only;
- linking an Endeavor to an agenda item preserves organization boundaries and one
  appearance per agenda;
- snapshot title, summary, and rich details remain independent; and
- approved and published agendas remain locked.

## Visual Direction

This is a terminology migration within **The 1919**, not a redesign. Preserve the existing
navy, gold, cream, docket rows, priority grouping, continuity spine, typography, spacing,
and responsive collapse. Replace labels with plain Endeavor language: the index explains
that Endeavors preserve continuing Post work; creation says “New Endeavor”; agenda actions
say “Add Endeavor.” The signature continuity spine remains the visual expression of work
carried across meetings and officer transitions.

Rendered review covers desktop and 390px widths, navigation, index/detail, creation,
append-only updates, agenda insertion, keyboard focus, and horizontal overflow.

## Explicit Boundaries

This milestone adds no minutes model, statuses or kinds, Pillar persistence, events,
documents, assignments, project-management features, dashboards, reminders, automation,
or AI identity decisions. A future minutes item may have an optional direct
`endeavor_id`; seeding must copy that identity deliberately while preserving independent
minutes wording.
