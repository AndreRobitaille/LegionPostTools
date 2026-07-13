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
Meeting**, **Membership Meeting**). An admin builds a meeting type by pulling
catalog items into it, ordering them, and customizing their wording **for that
template only**. When an item is added, its title/summary/rich-text body are
*copied* from the catalog into a template item; later edits to the template item
do not touch the catalog, and later catalog edits do not overwrite template
customizations.

**Meeting Instance** *(future — not built yet)* — an actual dated meeting's
agenda. It is *started from* a meeting-type template as a convenience, but is not
bound to it: an instance agenda may also include catalog items that are not in
the template (and, later, one-off items). A meeting instance is an official
record; a meeting type is not.

## How they relate

```
Agenda Item Catalog        Meeting Types              Meeting Instances (future)
(reusable items)     ──▶   (templates built     ──▶   (a meeting's actual agenda,
                            from catalog items)         seeded from a template, but
                                                        free to draw from the catalog
                                                        directly too)
```

Key points that are easy to get wrong:

- It is **not** a one-to-one mapping. A meeting instance's agenda is not required
  to match any meeting type, and can contain catalog items that no template uses.
- Meeting types do **not** subsume or replace the catalog. They are distinct tools
  at different levels — *items* vs. *arrangements of items*. The catalog stays
  independently reachable because meeting instances (and admins) draw from it
  directly, not only through templates.
- The copy is deliberate: templates capture a snapshot so a post can tune wording
  per meeting type without disturbing the shared catalog.

## In the app today

- Both the **Agenda Catalog** and **Meeting Types** are managed from the Admin hub
  (Meetings & Roster section), each as its own tile, gated on the `manage_agendas`
  capability. Catalog first, Meeting Types second — the order a user builds things.
- Meeting instances are a later roadmap phase and are not implemented yet.

## Related

- Meeting Types design: `docs/superpowers/specs/2026-07-13-meeting-type-templates-design.md`
- Admin hub design: `docs/superpowers/specs/2026-07-13-admin-hub-reorganization-design.md`
- `MeetingBody` is intentionally **not** used in this workflow (premature structure;
  see the meeting-type spec's Non-Goals).
