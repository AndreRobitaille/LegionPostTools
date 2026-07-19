# Meeting Types Admin Refresh Design

## Purpose

The meeting types admin area works but reads as an early scaffold. The index page
can't reorder or delete meeting types and exposes a technical "Seed default meeting
types" button. The edit page uses Up/Down buttons, a "Remove" button with a
confusing soft-delete, and a full form-submit to rename or (de)activate.

This refresh brings both pages in line with the Post Positions pattern
(`admin/position_titles`): drag-to-reorder, instant toggles, and low-ceremony
inline actions. It also removes the seeded/soft-delete machinery that leaked
technical concepts to officers, replacing it with a plain mental model: a
suggested starting list you can freely reorder, edit, and delete, plus explicit
"restore the defaults" actions when you want them back.

Audience: American Legion officers and adjutants, often in their 70s and low on
computer confidence. Favor clarity and large targets over cleverness.

## Product Boundary

In scope:

- Meeting Types index: drag-to-reorder, delete a meeting type, clearer default
  seed/reset buttons.
- Meeting Type edit: click-to-edit name, instant active toggle, drag-to-reorder
  agenda items, red trash-can delete, restore-agenda-to-default.
- Remove the soft-delete / inactive-in-list behavior for agenda items entirely.
- A shared `Reorderable` concern for the two unique-position models.

Out of scope:

- Any change to the agenda item catalog pages or catalog wording.
- Any change to dated agendas, minutes, or official records.
- Renaming "Add catalog item" / "Agenda Item Catalog" (kept as-is this pass).
- Per-row active/inactive toggles for agenda items (delete replaces them).

## Why deleting is safe

Meeting types and their agenda items are **templates only**. Dated agendas copy
template items into a dated agenda at creation time (a snapshot), so nothing
references a `meeting_type` except its own `meeting_type_agenda_items`
(`dependent: :destroy`). Deleting a meeting type or an item touches no official
record. This is what lets us drop soft-delete.

## The seeded/soft-delete simplification (core change)

Today, deleting an agenda item **soft-deletes** seeded items (marks them inactive
and keeps the row) so the additive, idempotent seeder won't recreate them on a
reseed. That surfaces "seeded" and "inactive" concepts an officer never asked
about, and leaves ghost rows in the list.

New model:

- **Delete always means delete.** No soft-delete anywhere. The agenda list and the
  meeting-types list only ever show what is actually there.
- **Restoring defaults is explicit and destructive-by-design.** Pressing a restore
  action returns you to the default list, full stop. There is no resurrection
  logic to reason about because the only thing that re-adds a default is a
  deliberate restore.

Two restore surfaces:

- **Index — suggested meeting types** (about the list of *types*):
  - When suggested types are missing: **"Add suggested"** — additive; creates the
    missing suggested types and their default items. Existing custom types
    untouched. (Powered by the current `MeetingTypeTemplateSeeder.seed_for!`.)
  - When all suggested types are present: **"Reset suggested"** — destroys the
    suggested types and their items, then recreates them from the template.
    Custom (post-created) meeting types are never touched.
  - The two are state-exclusive; only one shows, gated by the existing
    `defaults_missing?` check.
- **Edit — this meeting type's agenda** (about the *items* in one type):
  - **"Reset agenda to default"** — wipes this meeting type's agenda items and
    recreates them from the template's item list. Shown **only on suggested
    meeting types** (`seeded?`), because custom types have no template to restore.

"Suggested" is the officer-facing word for what the code calls seeded/default.

## Meeting Types index page

Layout mirrors Post Positions where it helps, but keeps the existing `.mrow`
card list for the type rows.

Row (per meeting type):

- Drag handle (`.pos-handle` grip, same SVG/markup as Post Positions).
- Name + item count (existing `.mrow-name` / `.mrow-sub`).
- Inactive indication stays for inactive types (existing `agenda_active_tag`).
- Edit affordance (existing).
- Red trash-can delete button, `turbo_confirm: "Delete this meeting type?"`.

Because rows become draggable, the whole-row `link_to` wrapper is restructured so
the drag handle and trash button are not inside the edit link. Follow the Post
Positions structure: a `data-controller="reorder"` wrapper, a
`data-reorder-target="list"` inner div, one row element per type carrying
`data-<something>-id`, and a `pos-status` live region.

Button row:

- "Add meeting type" (existing primary).
- "Add suggested" **or** "Reset suggested" (state-exclusive; see above).
  - "Reset suggested" carries `turbo_confirm: "Reset the suggested meeting types
    back to their defaults? Your changes to them will be lost."`
- "Agenda Item Catalog" (existing).

The "Added by your post" flag on custom types can stay or go; keep it only if it
still reads cleanly once rows are draggable. Default: drop it to reduce clutter,
consistent with removing the seeded/inactive language elsewhere.

## Meeting Type edit page

### Top: name and active (no form submit)

- **Name — click-to-edit.** Renders as plain text (`.mrow-name`-scale) with a
  small pencil **Edit** button. Clicking Edit swaps the text for an input and
  turns the button into **Save**, with a **Cancel** alongside. Save submits a
  Turbo PATCH to the existing `meeting_types#update` (name only) and returns to
  display mode with a brief "Saved" confirmation. Renaming stays deliberate; no
  page-level form submit.
- **Active — instant toggle.** A `button_to` that flips `active` immediately and
  reflects state in place, mirroring the Post Positions "Activate/Deactivate"
  control. Uses the existing `update` action (already permits `:name, :active`).

A small `inline-edit` Stimulus controller drives the name display/edit swap. No
controller changes are needed for either action.

### Template agenda: reorder and delete

- **Drag to reorder** via the **same `reorder` Stimulus controller** used by Post
  Positions (drag by grip, auto-save on drop, restore-on-failure, live status
  line). Replaces the Up/Down `button_to`s and the `move` action's UI.
- **Red trash-can delete** on every row, `turbo_confirm: "Remove this item from
  the agenda?"`. Always a true delete.
- The inactive tag and "Added by your post" flag are removed from item rows.

Section header keeps "Template agenda" and the "Add catalog item" button. Add a
**"Reset agenda to default"** button next to it, shown only when
`@meeting_type.seeded?`, with `turbo_confirm: "Reset this agenda back to the
default items? Your changes to this agenda will be lost."`.

## Backend changes

Routes (`config/routes.rb`):

- `resources :meeting_types` — add `:destroy`; add `post :reorder, on: :collection`.
- Nested `agenda_items` — add `post :reorder, on: :collection`. The `move`
  member route is removed once the UI no longer uses it.
- `resources :meeting_types` — add `post :reset_agenda, on: :member` for
  restoring one meeting type's agenda to default.

Shared concern (`app/models/concerns/reorderable.rb`):

- `reorder!(scope, ordered_ids)` that:
  1. Loads the scope's rows for `ordered_ids`; raises
     `ActiveRecord::RecordNotFound` unless every id resolves within the scope
     (guards against duplicates and foreign ids), matching `PositionTitle`.
  2. Rewrites positions in **two phases** inside a transaction: first move all
     rows to a high, non-colliding range (offset beyond current max), then set a
     contiguous `1..N`. This is required because both `meeting_types.position`
     and `meeting_type_agenda_items.position` have **unique** DB indexes, so the
     one-shot rewrite `PositionTitle` uses would collide mid-transaction.
- `MeetingType` and `MeetingTypeAgendaItem` use the concern, each pointing it at
  the right scope (organization's types / a meeting type's items) and position
  column. `PositionTitle` may adopt it later but is out of scope here.

Controllers:

- `MeetingTypesController#destroy` — destroy the type (items cascade), redirect to
  index with a notice. `#reorder` — call `MeetingType.reorder!` for the org,
  `head :ok` / `head :unprocessable_entity` like `PositionTitlesController`.
- `MeetingTypeAgendaItemsController#reorder` — `MeetingTypeAgendaItem.reorder!`
  for the meeting type, same head responses. `#destroy` simplifies to a plain
  `@item.destroy` (drop the seeded/soft-delete branch). The `move` action is
  removed.
- `MeetingTypesController#reset_agenda` — call the new seeder reset for the
  meeting type, redirect to its edit page with a notice.

Seeder (`MeetingTypeTemplateSeeder`):

- Add `reset_for!(organization)` — destroy the suggested meeting types (those
  matching `MEETING_TYPES` source keys) and their items, then `seed_for!`.
  Custom types are untouched.
- Add `reset_agenda_for!(meeting_type)` — destroy that meeting type's agenda
  items and recreate them from its definition's `item_source_keys`. No-op or
  guard if the meeting type is not a known suggested type.
- Keep `seed_for!` (additive) and `defaults_missing?` as-is; they power "Add
  suggested".

## Progressive enhancement

Reorder is progressive-enhancement, same as Post Positions: without JS the rows
render in saved order (not draggable). Delete, the name edit, and the toggle
degrade to standard Turbo `button_to`/form submits, so the page remains fully
usable without the Stimulus controllers.

## Testing

- Model: `Reorderable#reorder!` — happy path renumbers `1..N`; rejects foreign
  ids and duplicates; two-phase avoids unique-index violations for both models.
- Seeder: `reset_for!` restores suggested types to default and leaves custom types
  intact; `reset_agenda_for!` restores one type's items to default; both are
  idempotent.
- Controller/request: meeting type reorder, delete, and reset endpoints;
  agenda item reorder, delete (true delete, no soft-delete), and reset-agenda.
- System (if the suite runs JS): drag reorder persists on both pages; name
  click-to-edit saves; active toggle flips without a form submit.

## Accessibility and readability

- Drag handles carry `aria-label` naming their row, exactly like Post Positions.
- The red trash-can button has an accessible label ("Delete <name>" / "Remove
  <item title>"); red is not the only signal (icon + label).
- Meet the readability floor from the visual design system: body/interactive text
  >= 16px, secondary >= 14px, labels >= 13px. The trash-can and grip targets are
  at least as large as the Post Positions handle (28x32).
- Reuse existing tokens (`--color-red`, navy, muted); no new ad-hoc colors.
