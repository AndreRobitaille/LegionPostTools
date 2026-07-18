# Position Titles — Modern Reordering (Design)

**Date:** 18 JUL 2026
**Screen:** `/admin/position_titles`
**Status:** Approved design, ready for implementation planning.

## Problem

The Post Positions admin screen lists the offices a post fills. Two things
make it feel dated and error-prone:

1. **Adding a position asks for a manual "Order" number.** The add form has a
   number field pre-filled to `max + 1`. Officers should never think about
   order numbers when creating a role.
2. **There is no direct way to reorder.** Changing the sequence means editing
   `display_order` values by hand, which is not exposed as a real workflow.

We want reordering to feel modern: grab each row and drag it up or down.

## Audience constraint

The app serves American Legion officers and adjutants, often in their 70s,
some with limited dexterity or low computer confidence. This shaped two
decisions:

- **Drag must work on touch, not just mouse.** Native HTML5 drag-and-drop
  (`draggable` + `dragstart`/`dragover`) does **not** fire on touchscreens, so
  it is not an option. We use a pointer/touch-based library (SortableJS) so a
  finger on a tablet drags exactly like a mouse.
- **Auto-save on drop.** No separate "Save order" button to forget. The new
  order persists the moment a row is dropped, with a quiet confirmation.

**Known, accepted gap:** drag-handles-only offers no keyboard-only reordering.
This screen is admin-only, touched rarely (typically by the adjutant), so the
trade is acceptable. Not adding up/down arrow fallbacks.

## Solution overview

Replace the manual order field with append-to-end creation, and make every row
draggable by a grip handle. Persist reorders immediately through a dedicated
endpoint.

### 1. Reorder interaction

- Every row gains a **grip handle** (grey grip dots) on the far left. Only the
  handle initiates the drag; tapping the name or the toggle does not start a
  drag. The handle is a generous touch target.
- **SortableJS** (~11KB, zero runtime dependencies) pinned via importmap and
  **vendored locally** — no runtime CDN dependency. Wired through a thin
  `reorder_controller.js` Stimulus controller, matching the existing
  progressive-enhancement pattern (`rename_controller.js`).
- **Auto-save on drop:** on drop, the controller POSTs the full ordered list of
  IDs. On success, a subtle "Order saved" confirmation appears briefly; on
  failure, the list reverts to its prior order and shows an error.
- Works on desktop (mouse) and tablet/phone (touch).

### 2. Add-position form

- Remove the **"Order"** number field entirely. The add form becomes just
  **"Position name"** + **"Add position"**.
- On create, the server assigns `display_order = (current max) + 1` so the new
  position lands at the end. `display_order` is no longer user-facing and is
  dropped from permitted params.

### 3. Backend

- New route: `POST /admin/position_titles/reorder`.
- Payload: an ordered array of position-title IDs, e.g. `ids: [12, 5, 9, ...]`.
- Action updates each position's `display_order` to its index within a single
  transaction, **scoped to the organization** so a request cannot reorder or
  reference another org's records. IDs not belonging to the org are rejected.
- `create` sets `display_order` server-side (`max + 1`); `:display_order` is
  removed from `position_title_params`.
- A small `reorder!(ordered_ids)` method on `PositionTitle` (org-scoped) keeps
  the controller thin and testable.

### 4. Visual

- **Grip handle:** muted grey grip dots, cursor `grab` / `grabbing` while
  dragging. Row height and handle sized as a comfortable touch target
  (~44px row, ~24px handle column).
- **Layout:** handle + name grouped on the left; state + toggle grouped on the
  right. Nothing stranded (per the project's no-full-width rule).
- **Drag affordance:** the dragged row gets a subtle lift (shadow + slight
  opacity); a drop placeholder line shows where it will land.
- Type sizes follow the readability rules: name ≥ 16px, state label ≥ 13px.

## Data model

No schema change. `position_titles.display_order` (integer, default 0, not
null) already exists and is the sole ordering key alongside `name` as a
tiebreaker. Reordering rewrites `display_order` to contiguous indexes.

## Testing

- **Model:** `reorder!` writes contiguous `display_order` values in the given
  sequence; rejects IDs outside the org; is atomic (a bad ID leaves order
  unchanged).
- **Controller:** `reorder` persists a new order and returns success; rejects
  foreign IDs; `create` no longer accepts `display_order` and appends to the
  end.
- **System/JS behavior** (if system tests exist): dragging a row and dropping
  it persists the new order after reload. If no system-test harness is present,
  cover the controller/model contract thoroughly and verify the drag behavior
  manually in the running app.

## Out of scope

- Keyboard-only reordering (accepted gap).
- Deleting positions (existing activate/deactivate toggle is unchanged).
- Renaming positions inline (not requested here).
