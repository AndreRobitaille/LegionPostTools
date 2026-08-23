# Structured Agendas — Domain Model

This is the conceptual model behind the post's agenda tooling. It exists to keep
the levels straight, because the names are similar and the relationship is easy
to get backwards.

## The three levels

**Agenda Item Catalog** — the post-wide library of reusable *agenda items*
(building blocks). This is where an admin creates and customizes the individual
items a post reuses across its meetings (e.g. "Roll Call", "Reading of Minutes",
"Chaplain's Prayer"). The catalog is foundational: it is the source of items for
everything above it.

**Meeting Type** — a reusable *agenda template* for a kind of meeting (e.g. **PEC
Meeting**, **Membership Meeting**). An admin arranges named sections, pulls
catalog items into those sections, and customizes their wording **for that
template only**. When an item is added, its title/summary/rich-text body are
*copied* from the catalog into a template item; later edits to the template item
do not touch the catalog, and later catalog edits do not overwrite template
customizations.

**Dated Agenda** — an actual meeting's agenda. It is *started from* a meeting-type
template as a convenience, copying both the section structure and its items, but
is not bound to it afterward. Officers may rearrange sections and items or add
catalog items directly while the agenda is a draft. Approval and publication
lock the agenda until an authorized officer explicitly reopens it.

## How they relate

```
Agenda Item Catalog        Meeting Types              Dated Agendas
(reusable items)     ──▶   (sectioned templates  ──▶   (a meeting's sectioned agenda,
                            built from catalog items)   copied from a template, then
                                                        independently editable)
```

Key points that are easy to get wrong:

- It is **not** a one-to-one mapping. A dated agenda is not required
  to match any meeting type, and can contain catalog items that no template uses.
- Meeting types do **not** subsume or replace the catalog. They are distinct tools
  at different levels — *items* vs. *arrangements of items*. The catalog stays
  independently reachable because dated agendas (and admins) draw from it
  directly, not only through templates.
- Each level owns its copy. Templates can tune wording without disturbing the
  shared catalog, and dated agendas can adapt a meeting without altering the
  reusable template.
- Sections are first-class records at both the meeting-type and dated-agenda
  levels. Item positions are meaningful within a section, not across the entire
  agenda.

## In the app today

- The **Agenda Catalog**, **Meeting Types**, and **Dated Agendas** are managed from
  the Admin hub, gated on the `manage_agendas` capability.
- Meeting-type and dated-agenda editors present sections as numbered chapters.
  Officers can add, rename, remove, and reorder sections; add or move items within
  them; and use direct move controls as an accessible alternative to dragging.
- Approved and published dated agendas are read-only until explicitly reopened.

## Related

- Meeting Types design: `docs/superpowers/specs/2026-07-13-meeting-type-templates-design.md`
- Agenda Sections design: `docs/superpowers/specs/2026-08-22-agenda-sections-design.md`
- Membership Meeting structure: `docs/MEMBERSHIP_MEETING_AGENDA_STRUCTURE.md`
- Admin hub design: `docs/superpowers/specs/2026-07-13-admin-hub-reorganization-design.md`
- `MeetingBody` is intentionally **not** used in this workflow (premature structure;
  see the meeting-type spec's Non-Goals).
