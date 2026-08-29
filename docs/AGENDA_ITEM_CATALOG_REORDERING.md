# Agenda Item Catalog Reordering

## Purpose

Agenda managers need to arrange the post-wide catalog in the order that makes
sense when building American Legion meeting templates. An item may be reordered
inside its current category or moved to a different category without opening its
edit form.

The catalog remains a source library. Reordering or removing an entry does not
rewrite existing meeting-type templates or dated-agenda snapshots.

## Interaction model

- The six catalog categories remain fixed in the order defined by
  `AgendaItemCatalogEntry::CATEGORIES`.
- Every category is rendered, even when empty, so it is always available as a
  drop destination.
- A catalog row is draggable only from its visible grip. Dropping it in another
  category changes both its category and its position in that category.
- The complete catalog arrangement is saved atomically after each drop. A
  failed save restores every category to its pre-drag arrangement and gives a
  plain-language status message.
- Dragging is progressive enhancement. A quiet **Move** label followed by
  compact up/down arrow buttons provides the same operation without a pointer.
  Each arrow retains a full item-specific accessible name:
  - inside a category, the item moves one place;
  - at the first or last place, it crosses into the adjacent category;
  - the first catalog item's up arrow and the last catalog item's down arrow are
    disabled.
- **Edit** remains a separate, explicit link. The row itself is not a link,
  avoiding nested interactive controls and accidental edits while dragging.
- **Remove** uses the same compact red trash action as an item on a dated
  agenda. Its confirmation explains that the entry will leave the catalog while
  existing templates and dated agendas retain their independent copies.

## Data and integrity rules

- Positions are one-based and contiguous inside each category after a reorder.
- A reorder request must contain every catalog entry belonging to the current
  post exactly once and may contain no entry belonging to another post.
- Category names must come from the model's fixed category vocabulary.
- Validation and all category/position updates occur in one database
  transaction.
- New entries and entries whose category is changed in the edit form are placed
  at the end of their selected category.
- Removing an entry records when it left the catalog instead of physically
  deleting its database row. The entry no longer appears in the catalog or in
  Add-item choices, but references from existing templates and dated agendas
  remain intact.
- A removed seeded entry stays suppressed when the catalog seeder runs again.
- Seeding or resetting a meeting template also skips removed catalog entries;
  it cannot quietly reintroduce them into future meeting workflows.
- Reordering and position normalization consider only entries still present in
  the catalog.

## Visual direction

Subject: an American Legion adjutant maintaining the reusable order-of-business
library. Audience: officers who may have low computer confidence. Page job:
make the saved category and sequence unmistakable while keeping editing a
separate action.

The implementation extends the established **The 1919** visual system rather
than introducing a second design language.

### Tokens

- Legion navy `#0a2342`: section identity, grip focus, primary action ink.
- Service blue `#315b7d`: saved-state feedback and restrained interaction cues.
- Legion gold `#c6a15b`: the grip rail and category boundary emphasis.
- Ledger ivory `#fffdf7`: row and drop-zone surface.
- Rule tan `#eadfbf`: row divisions and quiet containment.
- Alert red `#b00020`: save failures only.

Typography continues the application's existing roles: its restrained serif for
page and section identity, system sans-serif for row content, and compact
uppercase utility text only for status flags.

### Layout

Desktop:

```text
CEREMONY ---------------------------------------------------  4 items
| grip | Item title and summary       | Move  ↑  ↓ | Edit | trash |
| grip | Item title and summary       | Move  ↑  ↓ | Edit | trash |

BUSINESS ---------------------------------------------------  0 items
|                 Drop an item here                         |
```

Narrow:

```text
CEREMONY ----------------------------------------- 4 items
| grip | Item title and summary                           |
|      | status flags          Move  ↑  ↓  Edit  trash  |
```

The signature element is the **grip rail**: the dotted handle sits on a narrow
gold-edged navy-tinted strip that visually binds ordering to the meeting's
order-of-business structure. During a cross-category drag, the destination
receives one deliberate inset gold rule; no decorative motion is added.

## Responsive and accessibility requirements

- All non-drag controls retain at least a 44-pixel touch target at narrow
  widths.
- Titles and summaries wrap without horizontal overflow at 390 CSS pixels.
- Handles have item-specific accessible names. Save status uses an ARIA live
  region.
- Keyboard focus is visible on handles, move controls, and Edit links.
- Reduced-motion preferences disable Sortable animation and CSS transitions.
- Empty drop zones include instructional text rather than relying on color.

## Acceptance checks

- Drag within one category persists a contiguous order.
- Drag from one category to another persists the new category and both orders.
- Move up/down crosses category boundaries correctly.
- Invalid, duplicate, incomplete, foreign-post, or unknown-category payloads
  change nothing.
- Removing a regular or seeded entry hides it from the catalog and Add-item
  choices without deleting existing template or dated-agenda copies.
- A removed seeded entry does not return after a subsequent seed.
- The catalog remains usable without JavaScript.
- Desktop and 390-pixel browser reviews show clear hierarchy, visible controls,
  drop feedback, and no horizontal overflow.
