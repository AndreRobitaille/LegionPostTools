# Dated Agendas — UI Design Pass

## Purpose

The dated-agendas feature (see `2026-07-18-dated-agendas-design.md`) is functionally
complete and tested, but most of its views ship as raw, unstyled placeholder HTML.
Only the two `admin/dated_agenda_items` views use the project's visual design system.
Every other screen — the admin index, the management/edit screen, the create form, all
member-facing views, and print — is bare `<h1>`/`<ul>`/`<p>` markup with unstyled
`button_to` actions.

This pass applies the established design system to every un-styled dated-agenda view so
the feature reads as a finished part of the app, meets the readability floor, and gives
Legion officers and members a clear, grounded workflow.

This is a UI/UX pass within an existing design system. It does not change the product
boundary, the data model, the lifecycle, or the authorization rules already specified.

## Base

This branch has been merged up to `main`. That matters because `main` landed a
meeting-types admin refresh whose infrastructure this pass reuses instead of rebuilding:

- `Reorderable` concern (`app/models/concerns/reorderable.rb`) exposing
  `reorder_within!(scope, ordered_ids, column:)` — atomic, two-phase, UNIQUE-index-safe.
  `MeetingTypeAgendaItem.reorder!` already wraps it; `DatedAgendaItem` follows the same
  shape.
- The `reorder` Stimulus controller is already generalized to `data-reorder-item` /
  `data-reorder-id` / `data-reorder-url-value`. **No JS change is needed** — the
  management screen just renders the established markup.
- The redesigned `admin/meeting_types/edit` drag-and-trash agenda list is the exact
  markup + CSS template for this feature's item list (see below).
- Shared reorder/row CSS (`.reorder-hint`, `.mrow-list [data-reorder-item]`,
  `.mrow .pos-handle`, `.row-del`) already exists in `application.css`.
- The system-test harness (`test/application_system_test_case.rb`,
  `system_sign_in`) exists, with `test/system/meeting_types_test.rb` as the pattern.

## Scope

In scope (all confirmed with the user):

- Restyle every un-styled dated-agenda view using the existing design vocabulary.
- Fix a site-wide date/time format violation in these views.
- Add a lifecycle status tag reusing the existing `.st` status-tag component.
- Convert agenda-item reordering on the management screen from Up/Down buttons to
  drag-and-drop, reusing the existing `reorder` Stimulus controller.
- Give print output a real `@media print` stylesheet.
- Update tests to match, and add one browser smoke test.

Out of scope:

- Any change to models, lifecycle transitions, authorization, or the product boundary.
- Minutes workflow, PDF generation, email distribution (already deferred upstream).
- Refactoring unrelated views or the sibling meeting-types feature beyond the one
  shared controller change noted below.

## Design System Reference

The feature reuses the vocabulary already established by the `meeting_types`,
`position_titles`, and `agenda_item_catalog_entries` admin screens:

- Page frame: `content_for :title`, `.back` link, `.page-lead` / `.page-title` /
  `.page-sub`.
- Item lists: `.mrow-list` / `.mrow` / `.catrow` with `.mrow-id` / `.mrow-name` /
  `.mrow-sub` and inline actions in `.catrow-meta` (`.catrow-edit`, `.catrow-flag`).
- Section headers: `.sec-head-row` + the `shared/section_header` partial.
- Buttons: `.btnrow`, `.btn-primary`, `.btn-secondary`.
- Forms: `.panel` / `.form-panel`, `.stacked-form`, `.fl`, `.f`, `.error-summary`,
  `.btnrow`.
- Status tags: `.st` / `.st-dot` with color variants (`StatusDisplayHelper`).
- Drag reorder: the generalized `reorder` Stimulus controller (`data-controller="reorder"`,
  `data-reorder-url-value`, `data-reorder-target="list"`/`"status"`, rows marked
  `data-reorder-item data-reorder-id="<id>"`), with `.pos-handle` / `.pos-ghost` /
  `.pos-drag` / `.pos-status` and `.row-del` for the trash button — exactly as used by
  `admin/meeting_types/edit`.
- Read-only hint: `.readonly-tip`.

The two already-styled item views (`admin/dated_agenda_items/new` and `edit`) are the
correctness reference and are left as-is. The redesigned `admin/meeting_types/edit`
(inline-edit header + drag/trash agenda rows) is the reference for the management
screen's agenda-item list.

## Cross-Cutting Fixes

### Date/time format

Every current dated-agenda view renders dates with `l(..., format: :long)` or
`strftime("%B %-d, %Y")` ("July 19, 2026"), violating the site-wide format rule
(dates `DD MMM YYYY`, times 24-hour `HH:MM`). The app already has `LegionFormatHelper`:

- `legion_date(value)` → `19 JUL 2026`
- `legion_time(value)` → `19:30`
- `legion_datetime(value)` → `19 JUL 2026 · 19:30`

All new views use these helpers. No view uses `format: :long` or ad-hoc `strftime` for
display. (The stored default title string generated at creation time is content, not a
display format, and is out of scope for this pass.)

### App shell

Every view gets `content_for :title`, a `.back` link to its logical parent, and a
`.page-lead` header block, matching the sibling admin screens.

## Lifecycle Status Tag

Add `dated_agenda_status_tag(status)` to `StatusDisplayHelper`, alongside
`agenda_active_tag`. It renders the existing `.st` / `.st-dot` component with a
per-status variant and label:

- `draft` → `.st--draft`, label "Draft" (muted grey; may alias `--other`)
- `approved` → `.st--approved`, label "Approved" (amber/gold)
- `published` → `.st--published`, label "Published" (green)

Because the existing `.st` component defines only `--active` / `--expired` / `--other`,
add two small variants to `application.css`: `.st--approved` (amber, e.g. a gold/ochre
token) and `.st--published` (green, reusing `--color-green`). `.st--draft` may reuse the
muted treatment of `--other`. No other status styling is introduced.

The tag is used on the admin index rows and in the management screen's lifecycle bar.

## Screen Designs

### Admin index — `admin/dated_agendas/index`

- `.back` to `admin_root_path` ("Administration").
- `.page-lead`: title "Dated Agendas", sub "Agendas for specific meeting dates."
- `.btnrow` with **New dated agenda** (`.btn-primary`).
- `.mrow-list`: each agenda is a `.mrow catrow` linking to its edit screen —
  `.mrow-name` = title, `.mrow-sub` = meeting body name + `legion_datetime(starts_at)`,
  and `.catrow-meta` carries the `dated_agenda_status_tag` plus a `.catrow-edit`
  "Edit ›" affordance.
- Empty state: a `.page-sub` line when there are no agendas.

### Admin management screen — `admin/dated_agendas/edit`

The centerpiece. Top to bottom:

1. `.back` to the admin index + `.page-lead`: `.page-title` = agenda title,
   `.page-sub` = meeting body name · `legion_datetime(starts_at)`.
2. **Lifecycle bar** — a row showing the current `dated_agenda_status_tag` and the
   actions valid for the state:
   - `draft`: **Approve** (`.btn-primary`, PATCH `approve`).
   - `approved`: **Publish** (`.btn-primary`, PATCH `publish`) + **Reopen for editing**
     (`.btn-secondary`, PATCH `reopen`, `turbo_confirm`).
   - `published`: **Reopen for editing** (`.btn-secondary`, PATCH `reopen`,
     `turbo_confirm` that warns members keep seeing the last published version until
     re-published).
   - When locked (approved/published), a `.readonly-tip` line: "This agenda is
     approved/published and locked. Reopen it to make changes."
3. **Details form** (`admin/dated_agendas/_form`) restyled as `.panel` /
   `.stacked-form`. In draft it shows editable fields (meeting body/type read-only after
   creation, date/time, title, hidden `lock_version`). When locked it shows a read-only
   summary instead of inputs. Optimistic-lock error surfaces via `.error-summary`.
4. **Agenda items** section: `.sec-head-row` + `section_header` "Agenda items", then
   **Add from catalog** (`.btn-primary`, draft only), then the item list:
   - **Draft** → drag-reorder list copied from `admin/meeting_types/edit`: a
     `data-controller="reorder"` wrapper with `data-reorder-url-value` pointing at the new
     reorder route, a `.mrow-list` `data-reorder-target="list"`, and one
     `.mrow.catrow data-reorder-item data-reorder-id="<id>"` per item — each containing the
     `.pos-handle` grip (same SVG), `.mrow-id` (name + optional summary as `.mrow-sub`),
     and a `.catrow-meta` with an **Edit** link (`.catrow-edit`) and a trash **Remove**
     button (`.row-del`, `turbo_confirm`). A `.pos-status` live region reports "Order
     saved". A `.reorder-hint` line explains the drag affordance.
   - **Locked** (approved/published) → the same rows rendered statically: no handle, no
     Edit/Remove, no add button, no reorder wrapper.
   - **Empty** → friendly guidance ("This agenda has no items yet. Add items from the
     catalog to build this meeting agenda.").
5. **Print** link to the admin print view.

### Create form — `admin/dated_agendas/new` + `_form`

- `.back` to the admin index + `.page-lead`: title "New dated agenda", sub explaining
  the action ("Create an agenda for a specific meeting date from a meeting type
  template.").
- `.panel` / `.stacked-form` with plain labels: **Meeting body**, **Meeting type**,
  **Date & time** (`datetime_local_field`), **Title** (optional, with helper text that
  it defaults from the meeting type and date).
- A `.page-sub` note: creating the agenda copies the meeting type's current template
  items into this agenda; if the template is empty, the agenda starts empty.
- `.btnrow` submit.

The `_form` partial is shared between new and edit; it branches on `persisted?` /
`draft?` exactly as today, only restyled.

### Member index — `dated_agendas/index`

- `.page-lead`: title "Upcoming Published Agendas", sub describing it.
- `.mrow-list` (or equivalently simple readable list) of published upcoming agendas:
  title links to the member show, `.mrow-sub` = `legion_datetime(starts_at)`.
- Empty state: "No upcoming published agendas are available yet."

### Member show — `dated_agendas/show`

- `.page-lead` masthead: meeting body name, `.page-title` = agenda title,
  `legion_datetime(starts_at)`.
- A **Print** button (`.btn-secondary`).
- The `_agenda_body` partial rendered for members.

### Agenda body partial — `dated_agendas/_agenda_body`

Shared by member show and both print views. Each active/ordered item renders as a
`<section>` with a clear heading (`≥` the readability floor), an optional summary line,
and the rich-text body. Styling favors large, legible type over density.

### Print — `layouts/print.html.erb` + `admin/dated_agendas/print` + `dated_agendas/print`

- The print layout gets a real `@media print` stylesheet (inline `<style>` in the
  layout, or a dedicated print CSS): clean masthead (post/body name, date/time, and — on
  the admin print — status), large readable body type, sensible page margins,
  `page-break-inside: avoid` on agenda-item sections, and suppression of all screen
  chrome (nav, buttons, links-as-controls).
- Both print views render the masthead + `_agenda_body` with no navigation or editing
  controls, satisfying the spec's "same content, controls removed" requirement.

## Drag Reorder

The management screen replaces the Up/Down `move` buttons with drag-and-drop, reusing
the infrastructure `main` already provides. **No Stimulus/JS change is required** — the
generalized `reorder` controller already exists; only the server side and the rendered
markup are new.

### Model

`DatedAgendaItem` includes the `Reorderable` concern and exposes a class method mirroring
`MeetingTypeAgendaItem.reorder!`:

```ruby
include Reorderable

def self.reorder!(dated_agenda, ordered_ids)
  reorder_within!(dated_agenda.dated_agenda_items, ordered_ids)
end
```

`reorder_within!` is atomic, two-phase, and safe with the existing
`UNIQUE(position, dated_agenda_id)` index; it raises `ActiveRecord::RecordNotFound` when
`ordered_ids` is not exactly the agenda's item ids.

### Route + controller

- Route: **replace** the existing `patch :move` with `post :reorder, on: :collection`
  on the admin dated-agenda `agenda_items` resource.
- Controller: add `Admin::DatedAgendaItemsController#reorder`, covered by the existing
  `require_capability("manage_agendas")` and `ensure_draft_agenda` filters (add `:reorder`
  to the `ensure_draft_agenda` filter list). It mirrors
  `Admin::MeetingTypeAgendaItemsController#reorder`:

```ruby
def reorder
  DatedAgendaItem.reorder!(@dated_agenda, params.require(:ids))
  head :ok
rescue ActiveRecord::RecordNotFound
  head :unprocessable_entity
end
```

### Remove the Up/Down path

Delete the now-redundant `move` action, its `patch :move` route, its `set_item`/
`ensure_draft_agenda` inclusion for `:move`, and its controller tests, so there is a
single reorder path — matching `meeting_types`.

**Accepted tradeoff:** drag-only reorder has no no-JS/keyboard fallback. The
`meeting_types` and `position_titles` features already made this same choice for the same
70+ audience, so this keeps the app consistent. Without JS the rows still render in saved
order; they just aren't draggable.

## Testing

- **Controller tests:** replace the `move` tests with `reorder` tests covering a
  successful reorder (positions persist in the posted order), a locked-agenda rejection
  (guarded by `ensure_draft_agenda`), and a bad id set returning `:unprocessable_entity`
  — mirroring `meeting_type_agenda_items_controller_test`.
- **Model test:** `DatedAgendaItem.reorder!` reorders within an agenda and raises
  `ActiveRecord::RecordNotFound` for an id set that doesn't match the agenda's items —
  mirroring `meeting_type_agenda_item_test`.
- **System test** (`test/system/dated_agendas_test.rb`, mirroring
  `meeting_types_test.rb`: `system_sign_in`, a `manage_agendas` grant, a meeting body +
  seeded meeting type + a dated agenda created from template): on the draft management
  screen the items render and `drag_to(..., html5: true)` reorders and auto-saves
  (`.pos-status` shows /saved/i); on an approved/published agenda no drag handles or
  edit/remove controls are present. This satisfies the upstream spec's browser-smoke-test
  expectation.
- Existing model/controller tests for creation, template independence, lifecycle, and
  member visibility remain unchanged.

## Verification Expectations

- Every dated-agenda view uses the design-system vocabulary; no bare
  `<h1>`/`<ul>`/`<p>` placeholder markup remains.
- No dated-agenda view uses `format: :long` or ad-hoc `strftime` for display; all dates
  and times go through `LegionFormatHelper`.
- Body/interactive text meets the readability floor (`≥ 16px`), per the visual design
  system spec.
- The management screen expresses lifecycle state clearly and hides editing controls
  when locked.
- The print output renders a clean, chrome-free, large-type agenda suitable for a member
  to hold at a meeting.
- The full test suite (`bin/rails test` and `bin/rails test:system`) passes.
