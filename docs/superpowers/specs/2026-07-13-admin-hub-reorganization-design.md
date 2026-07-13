# Admin Hub Reorganization — Design

**Date:** 2026-07-13
**Status:** Approved for planning
**Author:** Andre + Claude (brainstorming session)

## Problem

The admin area is a single scrolling page (`Admin::DashboardController#show`) with four
stacked panels — Roster, Post Positions, Administrators, and a Meeting Templates link.
It is already unwieldy, and the roadmap adds much more management surface (meeting
templates, meeting bodies, officer assignments, post identity, and eventually Records and
Tracked Items). A flat single page will not hold that growth.

Four specific pains, all confirmed:

1. **Too much on one scroll** — status (roster freshness) is mixed with configuration.
2. **A known pipeline of features** — the flat page won't scale to what's coming.
3. **Mixed concerns** — roster import sits next to permissions with no grouping.
4. **Discoverability** — a low-confidence officer can't quickly find the one task they came for.

## Audience

American Legion officers and adjutants, often 50–70+, frequently low computer confidence.
The design must favor plain language, large readable type (per the visual design system:
body/interactive ≥16px, secondary ≥14px, labels ≥13px), obvious targets, and one clear
choice at a time. It must respect Andre's standing UI rule: **no full-width boxes or
stretched rows with stranded actions** — status and action stay grouped with their subject.

## Chosen Direction

An **admin hub**: the landing page becomes a set of **bounded tile cards** grouped into a
few **topical sections**, each tile linking to a focused single-purpose page. This was
chosen over a persistent sidebar (too much chrome, leans enterprise, fights the
no-full-width rule) and over a grouped accordion (hides the scroll rather than solving
discoverability; deep forms in accordions are awkward). A plain full-width task list was
explicitly rejected — those are exactly the stretched rows Andre dislikes.

Tiles win *because* they are bounded: each is a small self-contained card that never
stretches to the window edge, and its action lives inside it.

### Sections and ordering

Three topical sections, **ordered by how often they are used** (frequency is expressed
through section order, not through dimming or a separate "Setup" shelf):

1. **Meetings & Roster** — the recurring, everyday work. *"Keep the membership current
   and prepare your agendas."*
2. **Officers & Elections** — changes roughly yearly, after an election. *"The offices
   your post fills and who holds them."*
3. **Setup & Administration** — rarely touched. *"Accounts, access, and post details."*

Naming note: "Meetings & Roster" pairs membership data with meeting prep, which is
slightly forced (roster is really membership). It is an accepted trade-off while the item
count is low; if membership tools grow, split a dedicated "Membership" section out later.

### Tile inventory

Real tiles link to focused pages. "Coming soon" tiles are dashed placeholders that show
the structure without implying the feature exists — consistent with the existing primary
nav "Soon" chips.

**Meetings & Roster**
- **Roster** *(real)* — carries its own status. When an import is due the tile turns amber,
  wears an "Import due" pill, shows the last-imported date, and holds the **Import roster**
  primary button. When current, it reads calm with a "View imports" action. This replaces
  the old full-width amber banner: status lives on its subject.
- **Agenda Catalog** *(real)* — links to the existing catalog page.
- **Meeting Templates** *(coming soon)*.

**Officers & Elections**
- **Post Positions** *(real)* — the offices the post fills, their wording, and their order.
- **Officer Assignments** *(coming soon)* — who currently holds each office (assignments
  live on person pages today; this is future centralization).

**Setup & Administration**
- **Administrators** *(real)* — who can administer the app; links to a focused list.
- **Post Details** *(coming soon)* — post name, number, department identity.

Icons: retained on tiles as lightweight recognition aids (they matched the app's tone in
review). They are decorative, not the primary signal — the text label carries meaning.

## Structural Changes

The hub is a menu; tiles link to focused pages. Two things that are inline on the dashboard
today must move to their own pages:

- **Post Positions** — extract the current inline list + add/reorder/activate controls into
  a focused `admin/position_titles#index` page. (Routes today expose only `create`/`update`;
  add `index`.)
- **Administrators** — extract the inline administrator list into a focused index page that
  lists current administrators, each linking to their person page where permissions are
  actually granted. (Add a route + controller/action.)

Roster imports and the agenda catalog already have focused pages and are reused as-is.

### Hub reachability and capability-aware tiles

Today the hub requires `manage_settings`, so agenda-only managers (`manage_agendas`) are
routed by the nav directly to the catalog, bypassing the hub. The redesign makes the hub
**reachable by any admin-capable user** and renders **each tile according to the viewer's
capabilities**:

- `manage_settings` sees all real tiles.
- `manage_agendas` without `manage_settings` sees the hub with only the tiles they can use
  (Agenda Catalog), and does not see Post Positions, Administrators, roster import, etc.
- A section with no visible tiles for the viewer is hidden entirely.

This removes the nav special-case and gives every admin a consistent front door. Each
underlying page keeps its own `require_capability` guard — the hub only decides what to
*show*; the pages remain the security boundary.

## Non-Goals

- No new functional features. "Coming soon" tiles are wayfinding only; nothing behind them
  is built here.
- No persistent sidebar, no accordion.
- No change to how permissions are granted (still per-person on the person page).
- No drill-through category pages — the hub is a single page with three sections; tiles go
  straight to the task.
- No Post 165 hard-coding; post-specific values stay in setup data/config.

## Visual & Layout Rules

- Tiles sit in an `auto-fill` grid with a fixed min/max column width (~250–290px) so a
  lone tile stays card-width and left-aligns — it never stretches to fill a row.
- No element spans the full content width: no banners, no stretched rows.
- Type sizes honor the visual design system minimums; secondary/muted text stays ≥14px.
- Dates render in the site format (e.g. `28 JUN 2026`); times 24-hour `HH:MM`.
- Reuse the existing visual language (`shared/section_panel` styling, button classes,
  status dot/pill patterns) rather than inventing new chrome.

## Success Criteria

- The everyday view is short: the recurring tasks (Roster, Agenda Catalog) are visible
  without hunting.
- No full-width boxes or stranded actions anywhere on the hub.
- Roster freshness is legible on the Roster tile itself.
- An agenda-only manager lands on the hub and sees only what they can do.
- Adding a future admin tool means adding one tile (and its page), not another scroll panel.
- The page passes a readability check against the visual design system minimums.

## Open Questions for Spec Review

1. **Capability-aware hub** — fold in now (recommended, removes the nav special-case), or
   keep the hub `manage_settings`-only for a first pass and leave agenda managers on their
   direct link?
2. **"Coming soon" tiles** — keep them for structural wayfinding, or show only built tiles
   until each feature lands?
3. **Administrators tile** — a dedicated focused list page, or is a lighter treatment
   (e.g. linking straight into the People area filtered to administrators) enough?
