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

Only **built** features get tiles. No "coming soon" placeholders — the hub shows what a
viewer can actually do, nothing more. Sections stay in place as the organizing frame and
fill in as features land, even while some sections hold a single tile today.

**Meetings & Roster**
- **Roster** — carries its own status. When an import is due the tile turns amber, wears an
  "Import due" pill, shows the last-imported date, and holds the **Import roster** primary
  button. When current, it reads calm with a "View imports" action. This replaces the old
  full-width amber banner: status lives on its subject.
- **Agenda Catalog** — links to the existing catalog page.

**Officers & Elections**
- **Post Positions** — the offices the post fills, their wording, and their order.

**Setup & Administration**
- **Administrators** — who can administer the app; links to a focused list.

Today that is four real tiles. The three sections will look sparse initially (Officers &
Elections and Setup & Administration each hold one tile); that is accepted — the sections
are the growth frame, and the names are ones officers recognize.

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

### Capabilities and access

Two coupled decisions drive the access model:

**Admins are the tool's tech support (full management access).** `manage_settings` becomes
a **superset** capability: holding it satisfies every *management* capability check, so an
administrator can step in and do things when other officers struggle — including opening
the Agenda Catalog without a separate `manage_agendas` grant. Today `User#can?` is a strict
exact-match; it will be changed so that a `manage_settings` grant implies the management
capabilities:

- Implied by `manage_settings`: `manage_people`, `manage_meeting_bodies`, `manage_agendas`,
  `manage_minutes`, `view_internal_records` (the configuration/management surface).
- **Not** implied — deliberately excluded: `approve_minutes`, `attest_minutes`,
  `record_acceptance_motions`. These are identity-bound official acts (attestation is
  effectively a signature); auto-granting them to a tech-support admin would undercut
  official-record authenticity. They remain explicit personal grants. *(Confirm — this is
  a product-philosophy call. See Open Questions.)*

The existing last-administrator protections (`another_enabled_manage_settings_user_exists?`,
`can_be_disabled?`) query `permission_grants` directly, not through `can?`, so the superset
change does not weaken them.

**Capability-aware hub, reachable to any admin-capable user.** The hub is no longer
`manage_settings`-only. It renders **each tile according to the viewer's capabilities** and
is reachable by anyone who can use at least one tile:

- A full admin (`manage_settings`) sees all four tiles.
- A `manage_agendas`-only manager sees the hub with just the Agenda Catalog tile; the
  Officers & Elections and Setup & Administration sections do not appear for them.
- A section with no visible tiles for the viewer is hidden entirely.

This removes the nav special-case (which currently routes agenda managers past the hub) and
gives every admin a consistent front door. Each underlying page keeps its own
`require_capability` guard — the hub only decides what to *show*; the pages remain the
security boundary, and they benefit from the same superset rule.

## Non-Goals

- No new functional features and no "coming soon" placeholders — only built tiles appear.
- No persistent sidebar, no accordion.
- No change to how permissions are *granted* (still per-person on the person page). The
  superset change affects only how a `manage_settings` grant is *interpreted*.
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

## Resolved Decisions

1. **Capability-aware hub — yes, folded in now.** The hub is reachable to any admin-capable
   user and renders tiles per capability, removing the nav special-case.
2. **No "coming soon" tiles.** Only built features appear.
3. **Admins get full management access.** `manage_settings` becomes a superset over the
   management capabilities so administrators can act as tech support. The Administrators
   tile links to a focused list of current admins, each handing off to their person page
   for grant changes.

4. **Attestation exclusion confirmed.** The superset excludes the identity-bound official
   acts (`approve_minutes`, `attest_minutes`, `record_acceptance_motions`); those stay
   explicit personal grants so a tech-support admin cannot sign/attest as though they were
   the officer.

## Guiding Principle

Keep the capability boundary simple. Do not build technical solutions for administrative
problems — the exclusion above is a plain capability line, not an enforcement/audit system.
If someone abuses their access, that is handled in the real world through discipline, not by
layering more machinery into the app. Applies to this work and future access decisions.
