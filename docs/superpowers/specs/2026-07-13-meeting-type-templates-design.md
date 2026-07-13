# Meeting Type Templates Design

## Summary

The next Structured Agendas phase creates an admin workflow for meeting types that also serves as the first agenda template maker. A meeting type is a reusable agenda template, such as **PEC Meeting** or **Membership Meeting**. Admins can create meeting types, choose existing Agenda Item Catalog entries for each one, order those items, and customize the wording for that meeting type only.

This phase uses existing catalog items only. A later roadmap item should add a guided flow to create a new catalog item from the meeting type editor and add it to the template.

## Goals

- Seed practical default meeting types for American Legion posts.
- Let agenda managers create additional meeting types.
- Let agenda managers build each meeting type from existing active catalog entries.
- Let agenda managers customize title, summary/guidance, and rich text wording for a specific meeting type without changing the post-wide catalog item.
- Keep the workflow understandable for older or low-confidence users.
- Avoid exposing confusing internal concepts such as `MeetingBody` in this workflow.

## Non-Goals

- No dated meeting agendas yet.
- No minutes lifecycle behavior yet.
- No inline creation of brand-new catalog items from the meeting type editor in this phase.
- No one-off freeform template items that are not backed by the Agenda Item Catalog.
- No search/filter requirement for the first catalog picker.
- No use of `MeetingBody` in the meeting type UI.

## Product Shape

A meeting type is a reusable agenda template. It is not a meeting occurrence and not an official record.

Seeded defaults:

- **PEC Meeting**
- **Membership Meeting**

Admins can add more meeting types in this workflow if their post needs them.

The Agenda Item Catalog remains the post-wide source of reusable agenda building blocks. When an item is added to a meeting type, the app copies the catalog item's current title, summary, and body into a meeting-type template item. Later edits to the template item affect only that meeting type. Later edits to the catalog item affect the catalog only and do not overwrite existing meeting type customizations.

## Data Model

Add a `MeetingType` model:

- `organization_id`
- `name`
- `slug`
- `position`
- `active`
- `source_key`
- `source_label`
- `seeded_at`

Rules:

- Organization-owned.
- Name is required.
- Slug is internal, derived from name, and unique per organization.
- Position controls display order.
- Seed metadata supports idempotent default creation without overwriting local edits.

Add a `MeetingTypeAgendaItem` model:

- `meeting_type_id`
- `agenda_item_catalog_entry_id`
- `position`
- `title`
- `summary`
- `active`
- `source_key`
- `source_label`
- `seeded_at`

It should use Action Text:

- `has_rich_text :body`

Rules:

- Each template item belongs to one meeting type.
- Each template item points to the source `AgendaItemCatalogEntry` it was copied from.
- The copied `title`, `summary`, and rich text `body` are meeting-type-specific editable fields.
- A catalog entry should not be added twice to the same meeting type.
- Template items must be scoped to the same organization through their meeting type and source catalog entry.

The existing `MeetingBody` model should not be used or exposed for this workflow. It appears to be premature structure for the current product direction. Retiring or removing it can be handled separately after confirming nothing else depends on it.

## Admin Workflow

Use the existing `manage_agendas` capability.

### Meeting Types Index

Add an admin page for meeting types.

The page should:

- list seeded and custom meeting types
- use the app's existing row vocabulary instead of a data-table feel
- show each meeting type's name, template item count, and inactive marker when relevant
- provide an obvious edit/open action
- provide a primary action to add a meeting type

### Meeting Type Form

The form should expose only officer-facing fields:

- name
- active toggle
- save/cancel controls

Do not show slug, source metadata, or position fields.

### Template Editor

Each meeting type has an ordered template editor.

The editor should show:

- meeting type name
- ordered list of template agenda items
- each item title and summary
- clear controls to edit wording, remove/deactivate from this meeting type, and move up/down
- an **Add catalog item** action

Removing or deactivating an item affects only that meeting type. It does not modify or deactivate the catalog entry.

### Catalog Picker

The picker should list existing active Agenda Item Catalog entries grouped by category in meeting-sensible order.

The picker should:

- show catalog item title and summary
- use the same scan/open row style as the catalog index
- allow selecting an item to copy it into the meeting type template
- indicate when an item is already in the meeting type and prevent duplicate adds
- exclude inactive catalog entries from new selection

Existing template items sourced from catalog entries that later become inactive should remain in the meeting type unless an admin removes or deactivates them.

## Seeded Defaults

Add a seeding service for meeting type templates. It should seed defaults per organization and be safe to run repeatedly.

Seeding should:

- create missing default meeting types
- create missing default template items
- avoid overwriting local edits to meeting type names, active status, order, or template item wording

### Membership Meeting

The Membership Meeting default should use the fuller standard meeting template. It should include ceremony/readings, normal officer/report slots, minutes, old or unfinished business, new business/correspondence, memorial or good-of-order items where appropriate, and closing material where appropriate.

### PEC Meeting

The PEC Meeting default should be a simpler business-focused template. It should not include opening or closing ceremony items and should not include officer reports by default. It should include essentials such as roll call/quorum, previous minutes, old or unfinished business, new business/correspondence, and a closing or general-good item if useful.

## Later Roadmap Item

Add a later enhancement for guided catalog creation from the meeting type editor:

1. Admin clicks **Add catalog item**.
2. The app first helps them look for an existing catalog entry.
3. If the item is missing, the app offers a guided **Create catalog item and add it here** path.
4. The new item becomes a real Agenda Item Catalog entry, then is copied into the meeting type template.

This keeps the catalog canonical while avoiding unnecessary screen-hopping in a later, more polished workflow.

## Error Handling and Constraints

- Only users with `manage_agendas` can manage meeting types and templates.
- Meeting type names must be present and unique per organization.
- Slugs are internal and automatically derived from names.
- Template items must not cross organization boundaries.
- Duplicate catalog entries in the same meeting type should be rejected with a clear message.
- Invalid form submissions should re-render with inline errors.
- If a catalog item is inactive, it should not be offered in the picker for new additions.

## Testing

Test coverage should include:

- `MeetingType` validations, slug behavior, ordering, and organization scoping
- `MeetingTypeAgendaItem` validations, catalog-source relationship, duplicate prevention, Action Text body, and organization consistency
- seeded default creation and idempotency
- no overwrite of local meeting type or template item edits on reseed
- permission gating with `manage_agendas`
- creating and editing meeting types
- adding existing catalog items to a meeting type
- template-specific wording overrides that do not modify the catalog
- moving items up and down
- removing or deactivating template items without changing catalog entries
- picker excluding inactive catalog entries while preserving existing template items
