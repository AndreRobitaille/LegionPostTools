# Meeting Type Hardening Design

## Summary

This patch hardens the newly added admin Meeting Types workflow without changing its core product shape. The goal is to remove unintended writes from read-only requests, make default seeding an explicit admin action, and protect meeting-type ordering from concurrent requests or double submits.

The product behavior stays simple for officers:

- the Meeting Types index remains the place to manage templates
- seeded defaults are still available when needed
- adding and reordering template items still works the same from the user's perspective

The main change is that default seeding becomes an intentional POST action instead of a side effect of visiting the page.

## Goals

- Keep `GET /admin/meeting_types` read-only.
- Make default meeting type seeding explicit and CSRF-protected.
- Prevent failed meeting-type form submissions from creating seeded records as a side effect.
- Reduce the chance of duplicate or inconsistent `position` values during concurrent create, add, or move operations.
- Preserve the current Meeting Types UI and officer-facing workflow as much as possible.
- Improve duplicate-add error handling so only the duplicate case shows the duplicate-specific message.

## Non-Goals

- No redesign of the Meeting Types pages.
- No change to which defaults are seeded.
- No new bulk ordering UI.
- No background jobs or broader initialization framework.
- No cleanup of unrelated agenda or admin dashboard code.

## Recommended Approach

Use an explicit admin POST action to seed defaults, plus transaction and locking hardening for position-sensitive writes.

Why this approach:

- It fixes the security issue directly by removing writes from GET requests.
- It matches Rails and browser expectations: reads stay reads, writes require POST.
- It keeps defaults available from the Meeting Types page instead of moving them into a separate operator-only task.
- It is a small patch over the current implementation, so it carries less product and code churn.

Alternatives considered:

1. Seed only from setup, migrations, or rake tasks. This is stricter, but less flexible if a post needs seeded defaults later.
2. Keep lazy seeding behavior but move it behind an inline prompt flow. This is workable, but adds more UI/state complexity than needed for this hardening pass.

## Product Behavior

### Meeting Types Index

The index should only load and display existing meeting types.

If the organization's default seeded meeting types are missing, the page may show a simple action such as **Seed default meeting types**. That action must submit a POST request.

The page must not create or modify records merely because it was visited.

### Seeding Defaults

Add an explicit admin route/action for seeding defaults:

- capability: `manage_agendas`
- request method: `POST`
- behavior: call `MeetingTypeTemplateSeeder.seed_for!` and redirect back to the Meeting Types page with a success notice

The seeder remains idempotent. Re-running it should fill in missing seeded records without overwriting local edits.

### Creating Meeting Types

Creating a meeting type should no longer trigger default seeding first.

If the submitted meeting type has no explicit position, the app should assign the next position inside a lock/transaction so concurrent creates do not choose the same value.

If validation fails, no seeded records or unrelated records should be created.

### Adding Template Items

Adding a catalog entry to a meeting type should calculate the next `position` inside a `meeting_type` lock so concurrent adds do not assign the same slot.

Duplicate catalog-entry adds should continue to be rejected with a friendly message.

Unexpected validation failures should not be mislabeled as duplicate-add errors.

### Reordering Template Items

Moving an item up or down should happen within a lock and transaction on the parent meeting type so the swap is atomic.

If there is no neighbor in the requested direction, the action should remain a no-op.

## Data Integrity Rules

### Position Assignment

The application should treat `position` as unique within:

- `organization_id` for `meeting_types`
- `meeting_type_id` for `meeting_type_agenda_items`

This uniqueness should be protected both by application locking and by database unique indexes.

### Locking Strategy

- Meeting type creation with automatic next-position assignment should lock the organization row.
- Template item creation and reordering should lock the meeting type row.
- Position-sensitive writes should run inside transactions.

This is intentionally simple and boring. The write frequency is low, and the admin workflow does not need a more elaborate ordering system.

### Existing Data Safety

Before adding unique position indexes, the migration should normalize any duplicate positions that might already exist in local/dev/test databases.

Normalization can be simple:

- for each organization's meeting types, reorder sequentially by current `position`, then `id`
- for each meeting type's agenda items, reorder sequentially by current `position`, then `id`

This keeps the existing relative order stable enough for this patch while making the new unique constraints safe to apply.

### One-Deploy Safety for Unique Index Migration

The unique-index migration must be a short blocking migration, not a concurrent one.

Reason:

- after normalization, old app code could still write duplicates before concurrent unique index creation finished
- a brief table lock avoids the deploy race and makes the migration safe in a single deploy

Implementation expectations:

- acquire a strong table lock on `meeting_types` and `meeting_type_agenda_items` before normalization
- replace the existing non-unique indexes with unique indexes in the same blocked migration
- keep the `down` path reversible for the index changes
- keep the lock window short by doing only the required normalization and index swap while locked

## Error Handling

- Duplicate template-item adds should show the current friendly duplicate message.
- Non-duplicate validation failures during add should surface as normal validation failures or a generic error path, not as a false duplicate message.
- Failed form submissions should re-render with inline errors as they do now.

## Routes and Controller Shape

Add a collection POST route under `admin/meeting_types` for default seeding.

Controller expectations:

- `index` is read-only
- `create` handles only meeting type creation
- `seed_defaults` handles default seeding
- `MeetingTypeAgendaItemsController#create` narrows duplicate rescue behavior
- `MeetingTypeAgendaItemsController#move` performs an atomic swap inside a lock/transaction

## Testing

Add or update focused tests for:

- `GET /admin/meeting_types` does not change meeting type or template-item counts
- `POST /admin/meeting_types/seed_defaults` seeds defaults and redirects correctly
- failed `POST /admin/meeting_types` does not create seeded defaults as a side effect
- duplicate-add path still shows the friendly duplicate message
- non-duplicate add failures are not mislabeled as duplicates
- move/add/create operations preserve unique positions in normal controller flows
- new migration/index expectations where model or schema-level assertions already exist

Concurrency itself does not need a heavy integration stress test in this patch. It is enough to verify that the write paths now use locks/transactions and that the schema enforces uniqueness for the ordering scopes.

## Verification

Minimum verification for this patch:

- targeted controller/model/service tests for meeting types and template items
- migration/schema verification through the test database

Broader checks can be run if the targeted tests reveal integration problems, but this patch does not require unrelated full-suite validation by default.
