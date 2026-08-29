# Dated Agenda Deletion Design

## Purpose and boundary

An officer with `manage_agendas` must be able to delete a dated agenda from its
management page regardless of whether it is draft, approved, or published. This is a
whole-record administrative action, not an edit to the locked agenda snapshot.

Deletion removes the dated agenda, its copied sections and items, and the items' rich
text. Source meeting-type templates, catalog entries, and linked Tracked Items remain.
The member-facing agenda disappears immediately if the record was published. The delegated
officer API now mirrors this operation at `DELETE /api/dated_agendas/:id`; the generated
handbook lists it under **Only when asked**, never as a routine agenda action.

## Interaction

The edit page ends with a quiet **Delete dated agenda** record-management section. Its
button opens a native modal dialog rather than deleting immediately. The dialog:

- names the exact agenda, meeting date, and current status in a compact record folio;
- explains that sections and items will be removed and cannot be recovered;
- explicitly warns that a published agenda will immediately stop being available to
  members;
- initially focuses **Cancel**, closes on Cancel, Escape, or a backdrop click, and
  restores focus to the opening button; and
- reserves the solid Legion red treatment for the final **Delete dated agenda** button.

The server continues to enforce `manage_agendas` and organization scoping. The browser
request redirects to the dated-agenda index with a completion notice; the API returns a
small description of the deleted record so the Bot can verify the exact target.

## Visual direction

The concrete subject is an American Legion meeting record in an officer's working file.
The screen's job is to make a rare destructive action discoverable without allowing it
to compete with approval, publication, or ordinary editing.

- Authority navy `#0A2240`
- Legion gold `#C6A15B`
- Paper cream `#FBF7EC`
- Ink `#1B222B`
- Muted text `#6B7684`
- Destructive red `#8C1622`

The existing system sans type is used for controls and explanation; Georgia is used only
for the agenda title inside the record folio, identifying the record rather than making
the warning theatrical. The signature element is that folio: a bordered, gold-ruled
summary of the exact snapshot being removed. The rest of the modal stays restrained.

```text
+--------------------------------------------------+
| PERMANENT ACTION                                 |
| Delete this dated agenda?                        |
|                                                  |
|  AGENDA RECORD                                   |
|  Membership Meeting — 04 AUG 2026                |
|  Membership · 04 AUG 2026, 19:00 · Published     |
|                                                  |
| This cannot be recovered.                        |
|                         [Cancel] [Delete agenda]  |
+--------------------------------------------------+
```

At phone widths the dialog keeps a 16px body-text floor, fits within the viewport, and
stacks both controls as full-width tap targets. Motion is limited to the browser's native
dialog behavior and respects the user's reduced-motion setting.

## Data integrity and verification

The existing item and section callbacks continue to reject direct changes to a locked
agenda. They permit destruction only when Rails identifies the whole dated agenda as the
destroying parent association, allowing normal dependent cleanup (including rich text)
without weakening snapshot locks.

Coverage should prove that:

- authorized deletion works for draft, approved, and published agendas;
- dependent sections, items, and rich text are removed while linked Tracked Items remain;
- direct item/section destruction on locked agendas remains blocked;
- unauthorized and cross-organization delete requests fail;
- the modal exposes the exact record and warning before submission; and
- desktop and 390px browser checks cover focus, Escape/Cancel behavior, deletion, and
  horizontal overflow.
