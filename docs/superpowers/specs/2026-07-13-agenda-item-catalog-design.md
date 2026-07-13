# Agenda Item Catalog Design

## Summary

LegionPostTools will build the Structured Agendas roadmap item in stages. The first stage is an organization-owned Agenda Item Catalog: a post-wide library of standard agenda building blocks and ceremony scripts that future meeting templates can reuse.

This phase does not create actual meeting agendas, meeting types, template builders, ad hoc agenda items, tracked annual topics, or minutes workflows. It creates the local catalog foundation those workflows will use later.

## Goals

- Give each American Legion installation a local, editable catalog of reusable agenda items.
- Seed a lean regular-meeting baseline from The American Legion Officer's Guide and Manual of Ceremonies.
- Store full ceremony/readings text where useful, so a post can adjust and save its own local wording.
- Classify catalog entries by human-facing category and future workflow behavior.
- Keep the catalog post-wide instead of scoped to a meeting body or meeting type.
- Avoid hard-coding Robert E. Burns Post 165 behavior.

## Non-Goals

- No meeting type creator yet.
- No agenda template builder yet.
- No actual dated meeting agendas yet.
- No ad hoc agenda items yet.
- No tracked annual topic/project system yet.
- No minutes lifecycle behavior yet.
- No broad ceremony library beyond the lean regular-meeting baseline.

Annual topics such as a car show, annual banquet, flag retirement ceremony, Buddy Checks, or similar recurring work should not be seeded as catalog items in this phase. They belong in later workflows as user-created meeting/template items or tracked long-lived topics.

## Product Shape

The Agenda Item Catalog is a post-wide library. It is not itself an agenda and not itself a template.

Each catalog entry belongs to an organization and can later be inserted into one or more meeting-type templates. Entries may be seeded from common American Legion meeting material, but seeded entries become local editable copies for the organization.

Catalog entries support:

- title
- slug
- short summary or guidance
- category
- behavior type
- full rich text body when applicable
- position for catalog ordering
- active/inactive status
- source metadata for seeded entries

The interface should explain the concept plainly: these are the standard building blocks the post can use when creating meeting templates later.

## Data Model

Create a model named `AgendaItemCatalogEntry` or another Rails-conventional equivalent.

Suggested fields:

- `organization_id`
- `title`
- `slug`
- `summary`
- `category`
- `behavior_type`
- `position`
- `active`
- `source_key`
- `source_label`
- `seeded_at`

The model should use Action Text:

- `has_rich_text :body`

Rich text body stores ceremony scripts, readings, default text, or longer guidance. Plain business placeholders may have a short body or no body.

Seed identity should be idempotent by organization and source key. Re-running seeds must not overwrite local edits.

## Categories

Categories are for human browsing and administration.

Initial categories:

- Ceremony
- Business
- Reports
- Membership
- Memorial
- Administration

Categories should be stored as stable enum-like values while displaying plain labels in the UI.

## Behavior Types

Behavior types describe how the app may treat an entry in later agenda/template/minutes workflows.

Initial behavior types:

- Scripted ceremony
- Section heading
- Report slot
- Business item
- Motion/vote item
- Reading/recitation

Examples:

- POW/MIA Empty Chair: Ceremony, Scripted ceremony
- Finance Officer Report: Reports, Report slot
- Old/Unfinished Business: Business, Section heading
- American Legion Preamble: Ceremony, Reading/recitation

The first phase should not over-automate behavior types. They are structural metadata for later phases.

## Admin Interface

Add an admin-managed catalog page, likely under `Admin -> Agenda Item Catalog`.

The index view should:

- group or filter entries by category
- show title, behavior type, active/inactive status, and source label
- provide edit links
- provide deactivate/reactivate controls
- allow creation of local catalog entries, but make management of the seeded baseline the primary path

The edit view should include:

- title
- summary/guidance
- category
- behavior type
- active toggle
- rich text body editor
- save/cancel controls

Permissions should use the existing `manage_agendas` capability. The catalog feeds agenda construction more directly than organization setup.

When editing a seeded entry, the UI should make clear that the user is editing the post's local copy only. Suggested wording:

> This changes your post's local copy only. It will not affect the original seed.

## Seeded Baseline Catalog

Seed a lean regular-meeting set based on The American Legion Officer's Guide and Manual of Ceremonies.

Ceremony and readings:

- Opening Ceremony
- Opening Prayer
- POW/MIA Empty Chair
- Pledge of Allegiance
- American Legion Preamble
- Closing Ceremony

Order-of-business and standard business items:

- Roll Call and Quorum
- Previous Meeting Minutes
- Introduction of Guests and Prospective/New Members
- Committee Reports
- Balloting on Applications
- Sick Call, Relief, and Employment
- Post Service Officer Report
- Unfinished / Old Business
- New Business and Correspondence
- Memorial to a Departed Post Member
- Good of The American Legion

Full-script entries should include the relevant ceremony, reading, or recitation text in the rich text body. Business/order items should include concise guidance explaining what the item is for.

The seed source label should identify the baseline clearly, such as `Officer's Guide regular meeting seed`.

## Future Path

Later phases should build on the catalog in this order:

1. Meeting type creator: define meeting types such as Monthly Membership Meeting or Post Executive Committee.
2. Agenda template builder: choose catalog entries and arrange them into the standard order for a meeting type.
3. Actual meeting agendas: generate dated agendas from templates with date, location, and meeting-specific preparation.
4. Tracked annual topics: represent long-lived work such as the car show, annual banquet, flag retirement ceremony, Buddy Checks, elections, and other continuing post business.

Agenda templates may eventually add per-template notes or instructions without changing the underlying catalog entry.

## Testing and Constraints

- Seeds are idempotent.
- Seeds do not overwrite local edits.
- Catalog management is permission-protected by `manage_agendas`.
- Rich text stays inside structured catalog records.
- Category and behavior values are validated.
- Catalog entries are organization-scoped.
- No behavior is hard-coded for Post 165.

## Open Product Judgment

The initial category and behavior-type lists should be treated as a practical starting point, not a permanent taxonomy. Additions are acceptable when later meeting templates or minutes workflows reveal a real need.
