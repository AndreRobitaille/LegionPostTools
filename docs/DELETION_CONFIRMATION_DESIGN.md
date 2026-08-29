# Record Deletion Confirmations

## Purpose

Agenda managers need one predictable confirmation pattern before removing a
catalog source, an item from a dated agenda, or an entire dated agenda. Native
browser confirmations do not provide enough hierarchy or room to explain what
will be lost and what will remain.

The shared confirmation must slow down an accidental click without making a
routine, deliberate removal difficult. It identifies the exact record, states
the scope of the action in plain language, and keeps the destructive action
visually separate from ordinary editing.

## Interaction model

- List pages use the established compact red trash icon. It opens an in-app
  modal and never submits the delete request directly.
- Edit pages repeat the same action in a separated danger zone below the form or
  record content so an officer does not have to return to the list to remove the
  record.
- Every modal includes:
  - an action-specific heading;
  - a short explanation of the deletion boundary;
  - a folio naming the exact catalog item, agenda item, or dated agenda;
  - a contextual warning or preservation note;
  - Cancel and a fully worded destructive button.
- Opening the modal focuses Cancel. Escape, Cancel, and a backdrop click close
  it and restore focus to the action that opened it.
- Only the final red button submits the delete request.

## Record-specific language

### Catalog item

“Remove from catalog” means a history-preserving removal. The entry disappears
from the catalog and future Add-item choices. Existing meeting templates and
dated agendas keep their independent copies, and seeded defaults do not restore
the removed entry.

### Dated-agenda item

The item and its meeting-specific wording, Commander notes, roll-call worksheet,
and other item-owned content leave this draft dated agenda. Its catalog source
and meeting template are not changed.

### Dated agenda

The dated agenda, sections, and items are permanently deleted. A published
agenda adds a prominent warning that members will immediately lose access.

## Visual direction

Subject: an American Legion adjutant checking the record folio before removing
meeting material. Audience: officers who may have low computer confidence.
Single job: make the scope and consequence unmistakable before the final action.

The modal extends the established **The 1919** visual system:

- Legion navy `#0a2342` for record identity and headings.
- Legion gold `#c6a15b` for the folio rule and focus ring.
- Ledger ivory `#fffdf7` for the identified record.
- Legion red `#b00020` only for the destructive boundary and final action.
- Service blue `#315b7d` for preservation notes that explain what remains.

The signature element is the **record folio**: a gold-ruled inset naming the
exact record and its meeting context. It turns a generic “Are you sure?” into a
specific records decision.

Desktop:

```text
┌ red rule ─────────────────────────────────────────────┐
│ REMOVE AGENDA ITEM                                    │
│ Remove this item from the dated agenda?               │
│ Scope explanation                                     │
│ ┌ gold rule  RECORD TO REMOVE                         │
│ │ Roll Call and Quorum                                │
│ │ Membership Meeting · Administration                 │
│ └                                                     │
│ Preservation note                                     │
│                              [Cancel] [Remove item]    │
└───────────────────────────────────────────────────────┘
```

At 390 CSS pixels, the dialog actions stack full-width with Cancel last in DOM
focus order but visually below the destructive action only where the existing
column-reverse pattern places it. The modal stays within the viewport and its
content scrolls if necessary.

## Acceptance checks

- No catalog, dated-agenda-item, or dated-agenda list deletion uses a native
  browser confirmation.
- List trash icons and edit-page danger zones open the same modal design.
- The modal identifies the exact record and accurately distinguishes retained
  data from deleted data.
- Cancel, Escape, and backdrop clicks close the dialog and restore trigger
  focus.
- The final action submits once and reaches the existing scoped controller
  deletion logic.
- Desktop and 390-pixel reviews show no overflow, clipped copy, or undersized
  touch targets.
