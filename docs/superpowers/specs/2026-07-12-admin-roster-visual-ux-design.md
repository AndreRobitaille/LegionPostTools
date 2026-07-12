# Admin & Roster — Visual / UX / IA Design

This spec captures the visual, UX, and information-architecture design for the
roster-backed administration slice (shipped functionally on 2026-07-11), plus a small set
of import **behaviors** promoted to first-class here. It was developed through a
brainstorming + visual-companion session on 2026-07-12.

It builds on two existing documents and does not restate them:

- Feature scope / domain rules: `docs/superpowers/specs/2026-07-11-admin-and-roster-import-design.md`
- Visual language ("The 1919" Art Deco), palette, type, readability floors, component
  vocabulary: `docs/superpowers/specs/2026-07-11-visual-design-system-design.md`

Interactive mockups for every screen below persist (gitignored) under
`.superpowers/brainstorm/` and are the visual source of truth where wording here is
ambiguous.

## Problem

The merged admin/roster slice is functionally complete but was shipped on **bare, unstyled
HTML** — "The 1919" stops at the door of Admin, the screens don't meet the readability
floors, and Admin is reachable only via a small top-right text link. This pass brings the
whole admin/roster surface onto the design system, reworks navigation, introduces a
member-facing People view, and formalizes a few import behaviors surfaced during design.

## Scope

**In scope**

- Primary navigation bar and app shell (shared with future sections).
- People directory — officer (data-rich) and member (limited) views.
- Person detail — officer (full) and member (limited) views.
- Roster import — upload, result summary, and import history/log.
- Admin landing (roster · post positions · administrators).
- First-class import behaviors: **removal detection + auto-disable sign-in**, and the
  **import history/log**.

**Out of scope (explicitly deferred)**

- Cleanup surface for **orphaned accounts** (a login whose person has no roster line). The
  removal flow disables sign-in; a later slice handles reviewing/deleting orphaned logins.
- The future sections themselves (Meetings, Records, Tracked Items) — only their disabled
  nav tabs appear.
- Dashboard redesign (tracked separately).
- Editing roster fields locally (roster stays read-only; corrections flow through National).

## Navigation & Information Architecture

Realize the **full intended nav bar now** (navy-2 tab strip, tracked uppercase labels, gold
underline on the active tab):

```
DASHBOARD   MEETINGS·   RECORDS·   TRACKED ITEMS·   PEOPLE   SETTINGS        ◆ ADMIN
            (· = shown but disabled, muted, "SOON" tag)                       (gold, gated)
```

- **People** is promoted to a first-class destination (out from under `/admin`).
- **Meetings / Records / Tracked Items** occupy their final slots now, rendered disabled
  with a muted "SOON" tag, so the shell is stable for future work.
- **◆ Admin** sits at the right end, in gold, set apart by a divider — a permission-gated
  (`manage_settings`) utility, not a peer section. Only shown to users who can administer.
- **Settings** is the user's own account (existing).
- The compact header keeps: emblem + post name/location (configurable, no hard-coded Post
  165), the current user with role + gold avatar, and Sign out. The Admin text-link moves
  out of the header into the nav bar.

### The two-view model

People and the person page render at **permission-appropriate depth**:

| | Member (any signed-in user) | Officer (`manage_people` / `manage_settings`) |
|---|---|---|
| People tab visible | Yes | Yes |
| ◆ Admin tab visible | No | Only with `manage_settings` |
| List columns | Name, office, branch·era | + status, paid-through, sign-in state |
| List filters | Search + sort only | + member status, paid-through, sign-in |
| Person page | Contact + Service + Post Roles (read-only) | + full Roster Record, Login Account, permissions, editable roles |

**Member-visible person fields:** name, office(s) held, branch of service, war era,
continuous years, and **contact (email + phone)**. **Officer-only:** mailing address,
dues / paid-through, member status, undeliverable flag, Member ID, the login account &
permissions, and all edit controls.

## Visual vocabulary (applied to admin)

All screens honor the system's hard rules — bounded columns (app frame ~1060px, content
often narrower/centered), **no full-width stretched rows** (a status and its action sit
together, never flung to the far edge), cream over white, and the readability floors
(interactive/body ≥16px, secondary ≥14px, labels ≥13px).

- **Section panel** — the primary container. A bordered, rounded card with a tinted ◆
  header strip (label in tracked navy caps, optional right-aligned provenance/action) and a
  padded body. Sections must read as distinct boxed units, not headings over open space.
- **Member/list row** — de-noised. Identity (name + gold tracked-caps office) on the left;
  a quiet left-aligned membership column at a divider on the right, using **label: value**
  (`Paid through: 2026`, `Sign-in: Yes`) with the status word as a colored headline. No
  boxed pills stacked at equal weight. Officers carry a subtle **gold left-edge**; type is
  **identical** for officers and non-officers.
- **Status** — a quiet colored word + small dot (green Active, hollow-red Expired), never a
  loud pill. **Red is reserved** for problems/attention and destructive actions only.
- **PUFL** — "Paid up for life" shown as quiet gold text (an honor), not a badge.
- **Sign-in state** — three labeled states: **Yes** (can sign in), **No** (turned off),
  **No account**. The disable action reads **"Disable sign-in"** with the helper "Keeps
  their record and roles — they just can't sign in until re-enabled."
- **Stat tiles** (import result) — large legible count tiles; semantic color (Created green,
  Updated navy, Removed bronze, Problems red **only when > 0**).
- **Buttons** — primary navy; confirm/finalize gold; secondary navy-outline; destructive/
  return red-outline.
- **Dates & times** — every displayed date is `DD MMM YYYY` (e.g. `24 JUN 2026`), every
  time is 24-hour `HH:MM`. Date inputs are **type-or-pick** (type `DD MMM YYYY` or open a
  calendar), never a locale-locked native picker.

## Screens

### People — list (officer view)

Single centered column. Search field + a compact filter bar **directly above the results**
(not in a sidebar): **Member status** (dropdown), **Paid through** (dropdown built only from
years present in the data, plus "Paid up for life"), **Can sign in?** (Yes / No / No
account). Branch is **not** a filter. A **Sort** control (Name A–Z, Member ID, Paid through,
Status) on the "All Members" header; **no pagination** — the roster scrolls. **Post
Officers** surface in a short group at the top, then All Members. Roster freshness shows as a
quiet pill near the title.

### People — list (member view)

Same clean list, stripped: no ◆ Admin tab, no status/paid/sign-in, no officer filters —
search + sort only. Officers still group at top. Rows open the member (limited) profile.

### Person — officer (full) view

Centered column. Identity header (name, office, status — no redundant service subline, since
it lives in the record). Then boxed panels:

- **◆ Roster Record** — read-only key/value grid of imported National fields, a 🔒
  provenance line ("National roster · imported `DD MMM YYYY`"), and a plain note that
  corrections are made at National and picked up on the next import.
- **◆ Login Account** — "Signs in as …" + "Can sign in" badge; the **roster/login
  email-mismatch** warning with inline resolution (use roster email / keep current);
  **Permissions** shown as an always-visible **vertical checklist grouped by category**
  (Administration / Meetings / Approvals / Records) with Save; and **Disable sign-in**
  (red-outline) with helper.
- **◆ Post Roles** — current and past assignments with `DD MMM YYYY` dates; every role has
  **Edit dates** (start/end correctable via type-or-pick fields), current roles have **End
  role**, and an assign-role form (Role dropdown + Starts on).

### Person — member (limited) view

Identity (name, office, branch·era) + boxed panels: **◆ Contact** (email + phone as
tap-to-reach links), **◆ Service** (branch, war era, continuous years shown as an honor),
**◆ Post Roles** (read-only). No record, account, permissions, or edit controls.

### Roster import — upload

Guided: three plain steps (export from National → choose file → upload), a large file
drop/choose area accepting the standard National `.csv`, and an honest **"what happens"**
note stating that this roster becomes the source of truth — matched by Member ID, anyone not
in the file is removed and their sign-in turned off, imported fields stay read-only. Upload
runs the import and lands on the result.

### Roster import — result

A green confirmation ("Roster import complete" + file, `DD MMM YYYY · HH:MM`, by whom). Four
tiles: **Created / Updated / Removed / Problems**. A **◆ Removed** panel lists members
dropped from National and states their sign-in was turned off (with reassurance a mistaken
removal returns on next import, record and roles kept). A **◆ Problems** panel states, per
row, **what happened → the effect → the fix** (usually: correct at National → re-import),
linking the affected person where a row partially imported. Actions: View People / Import
another / View import history.

### Admin landing

Gated hub, boxed panels:

- **◆ Roster** — freshness banner (current, or amber when > 30 days / never), an Import
  action, and **Recent imports** (the history log): each entry shows date/time, file, who,
  the created/updated/removed/problems summary, and Complete/Failed status, linking to that
  result; "View all imports →".
- **◆ Post Positions** — the offices assignable to people (name, active/inactive, order,
  add/edit). Config home for the roles shown on person pages.
- **◆ Administrators** — read-only overview of who holds app-admin, with the safety note
  that permissions are granted on each person's page and the **last enabled administrator
  cannot be removed or disabled**.

## First-class behaviors

1. **Removal detection.** An import compares the incoming file against existing
   roster-backed people (by Member ID). A person previously present but **absent from the
   new file** is marked **removed** (their roster data is retained, not deleted). Counted in
   the result's Removed tile and listed.
2. **Auto-disable sign-in on removal.** When a person is removed, their login account (if
   any) is **disabled** in the same import transaction — they have left the post and should
   not retain access. The last-enabled-administrator guard still holds (a removal that would
   disable the final admin must surface as a problem rather than silently locking everyone
   out). Re-appearing on a later import does **not** auto-re-enable sign-in; an officer
   re-enables deliberately.
3. **Import history / log.** Every import (already persisted as a `RosterImport` record) is
   surfaced as a browsable history: recent entries on the Admin landing and a full list, each
   opening its result summary. Includes failed imports (with the failure reason).

## Deferred / follow-ups

- **Orphaned-account cleanup** — reviewing/removing logins whose person has no roster line.
- **Filters-to-dropdowns** for member status / paid-through are delivered here; branch filter
  intentionally removed.
- Visual polish consolidation of the Admin landing (tighten row rhythm; reuse one row
  vocabulary across imports / positions / administrators).
- Tailwind theme tokens + reusable partials (panel, section header, member row, stat tile,
  type-or-pick date field, status word) so screens compose from one vocabulary.

## Open questions

- Exact **member status** values to offer in the filter dropdown (built from real roster
  values; confirm the National status vocabulary).
- Whether "Removed" should also appear as a filter/segment in the officer People list, or
  stay result-only.
