# Visual Design System and UI Concept

This spec captures the visual language and UI patterns for LegionPostTools, established
through a design exploration on 2026-07-11. It is the reference for building real UI on
top of the current plain-HTML scaffolding. It defines *how the app looks and behaves*, not
the domain model (see `docs/ARCHITECTURE.md`) or the feature scope (see the foundation and
meetings design).

Interactive mockups for every pattern below were built in the brainstorming visual
companion and persist (gitignored) under `.superpowers/brainstorm/`. They are the visual
source of truth if wording here is ambiguous.

## North Star: "The 1919" (Art Deco)

The American Legion was founded in 1919, into the Art Deco age. The visual identity draws
on that founding-era heritage — convention and Liberty-Loan poster graphics — rather than
office-supply metaphors (no notebook/ledger/form skins) or a generic app template.

Signature devices:

- **Sunburst rays** (which the official emblem already contains).
- **Stepped gold plates and frames**, monumental symmetry.
- **Tracked-out uppercase capitals** for mastheads and labels.
- **Diamond dividers** (◆) as the recurring Deco motif and section marker.

Two hard constraints learned during the exploration, which all screens must honor:

1. **No full-width / 100% layouts.** Full-bleed rows strand a status on one side of the
   screen from its action on the other. Content lives in **bounded columns** (app frame max
   ~1060px), and **a status and its action always sit together** on the same row or card.
2. **The monumental hero is reserved for entry moments** (login), never persistent chrome.
   Working screens use a compact header so no screen loses real estate to a giant strip.

## Palette

Warm and civic, never a glaring white screen (cream reduces glare for older eyes).

| Token | Hex | Use |
|-------|-----|-----|
| Navy (primary) | `#0A2240` | Header, primary buttons, document titles, authority |
| Navy 2 | `#0d2c54` | Nav bar, secondary navy surfaces |
| Navy deep | `#081a34` | Hero gradient base |
| Gold (accent) | `#C6A15B` | Rules, borders, confirm/finalize action, Deco accents |
| Gold highlight | `#E6CD8B` | Gold text on navy, emblem highlights |
| Cream (app bg) | `#F4EEDD` | The everyday page background ("paper") |
| Card paper | `#FBF7EC` | Rail cards, panels |
| Document ivory | `#FCFAF1` | Rendered official documents |
| Red (emphasis/attention) | `#8C1622` | The *only* loud color; return/decline actions and AI-flag markers |
| Ink | `#1b222b` | Body text |
| Muted | `#6b7684` | Secondary text |
| Green (done/added) | `#3f6b3f` | "Added", "Finalized", positive state |
| Bronze field | `#2a2018` → `#140d08` | Permanent-record ("sealed") surface |
| Bronze rule / warm gold | `#6e5a2b` / `#b98f46` | Permanent-record borders and labels |

Red discipline: red is the single loud color. It appears **only where a human decision is
required** (attention/edit) or on a destructive/return action. Everything else stays calm.

## Typography

- **App chrome / working UI:** system sans (`system-ui, "Segoe UI", Helvetica, Arial`).
  Legible and unfussy for less computer-confident users.
- **Official rendered documents (agendas, minutes):** serif (`Georgia, "Times New Roman"`).
  Reserving serif for documents makes an official record instantly *look* different from
  the tool used to edit it — reinforcing the authenticity/immutability boundary.
- **Deco display treatment:** uppercase with wide letter-spacing (~.12em–.42em) for
  mastheads and section labels; diamond (◆) dividers.
- A dedicated geometric/Deco display webfont may be adopted later; the system stack is the
  starting point.

### Minimum readable sizes (hard rule)

The primary audience is members in their 70s, many with low computer confidence, so type
must be large. These are floors, not targets — prefer erring larger, and never tighten type
for density:

- Body and interactive text (inputs, buttons, links, list rows): **≥ 16px**.
- Secondary / helper / caption text: **≥ 14px**.
- Field labels and small uppercase labels: **≥ 13px**.
- Nothing meaningful below **13px**; only purely decorative marks (e.g. the ◆ dividers) may
  be smaller.
- Page and section titles scale up from the body baseline (e.g. login title ~26px).

This rule overrides any mock or earlier screen that used smaller sizes. When adding a new
screen, check every font-size against these floors before shipping.

## The Emblem

Use the **official American Legion emblem** (downloaded from
`legion.org/.../emblem-and-brand-mark-download`; see the `emblem-brand-assets` memory). The
full-color emblem carries its own sunburst rays and suits large/hero placement. For very
small placements (e.g., the ~32px header mark) the official simplified **brand-mark** may
read more cleanly. The emblem is a protected trademark; internal post use is customary.
Place the asset in `app/assets/images/` during implementation.

## Application Shell

- **Compact header** (~54–56px, navy, gold bottom rule): small emblem, post name +
  location ("Post 165 / Two Rivers, WI"), and the current user with their **role**
  ("John Doe · Adjutant") plus a gold avatar. Configurable — no hard-coded Post 165.
- **Primary nav** (navy-2 tab bar): uppercase tracked labels, gold underline on the active
  tab. Sections: **Dashboard, Meetings, Records, Tracked Items, People, Settings.**
- **Page bar:** breadcrumb + page title + a record-status pill where relevant.
- **Working area:** cream background; a main column plus a context **rail** on the right.

## Entry / Login

The full monumental Deco hero is the **login screen**: navy field with faint sunburst rays,
a stepped gold plate holding the emblem, the post name in tracked capitals, a diamond
divider, and a location/charter line. Below sits a warm cream **sign-in card** designed for
low confidence:

- One large labeled email field, one large primary button ("Send my sign-in link").
- Plain reassurance ("no password to remember; the link works once and expires shortly").
- Passkey sign-in offered as a clearly secondary option.

## Component Vocabulary

- **Buttons:** primary (navy fill); confirm/finalize (gold fill); secondary (navy outline);
  quiet (underlined text link); return/decline (red outline).
- **Record-status pills:** Draft (gold-on-cream), Finalized (green), Attested · Official
  (navy/gold).
- **Section header:** diamond ◆ + uppercase tracked label + gold gradient rule; an inline
  "+ Add item" affordance where appropriate.
- **List / item row:** everything on one line — drag grip, title, minimal state, action.
  Importance is a **subtle gold left-edge** on the row (not a badge); a plain
  "⚠ needs notes" flag appears only when action is due. Once an item is seated/decided,
  it is quiet: no importance/expected-action badges pile up on it.
- **Cards / rail panels:** paper background, thin border, a diamond+label header.
- **Fields:** large, legible, generous padding.
- **Workflow stepper:** done (navy fill + check), current (white with gold ring), upcoming
  (muted).
- **AI-flag marker:** a red **"✎ Fix N"** pencil tag, with the flagged text carrying a faint
  red tint and red dotted underline. Each marker maps one-to-one to a short review list in
  the rail. This is the single, consistent way AI uncertainty is surfaced.

## Prioritization Model (choosing what to bring to a meeting)

Prioritization earns its place on the **selection side** (deciding what to pull onto an
agenda), not on already-seated items. It uses Eisenhower / *7 Habits* thinking rendered as
**plain buckets**, so the officer reads plain English while the matrix does the work
underneath:

- **Important & Urgent — Necessity:** belongs on this agenda.
- **Important · Not Urgent — Focus:** the forward work; raise when there's room.
- **Urgent · Not Important — Delegate:** handle quickly or hand off.
- **Not Urgent · Not Important — Keep tracking:** stays in the tracker.

Rules:

- **No "Q1–Q4" labels** — they read as fiscal quarters and carry no meaning in a list.
- Each item shows a plain **reason** ("Event is May 25 — planning must start"), which is
  more useful than a bare "Important" tag.
- Items **auto-sort** into buckets from two fields on a tracked item: an **importance**
  level and an optional **raise-by / target date** (a near date makes it Urgent). The
  officer never thinks in axes.
- Covey's literal Q3/Q4 names ("Distraction"/"Waste") are **softened** to "Delegate" /
  "Keep tracking" so no comrade's project reads as an insult.
- In the Agenda Builder, the rail shows a compact **"Bring to this meeting"** surface (the
  Necessity items, each with reason + Add), and **"See all business to consider →"** opens
  the full four-bucket panel.

## Agenda Builder

- **Left (main):** the seated agenda as clean, quiet sections (diamond + gold-rule headers)
  with plain item titles — gold edge for important, "needs notes" flag where due.
  Expected-action labels (Vote/Report) appear on the **printed** agenda, where attendees
  use them, not on the editing screen.
- **Right (rail):** Meeting Details; the "Bring to this meeting" prioritization surface;
  and a **Finalize** card that states the consequence in plain words ("Finalizing locks the
  version you distribute").

## Minutes: Numbered Official Record + Lifecycle

Official minutes render as a **formal numbered record**, which is both the authority cue and
a way to reference any decision:

- Numbered sections (1, 2, 3…), decimal sub-items (2.1, 2.2, 3.1), and **numbered motions**
  ("Motion 3.1 … Moved / Seconded / Carried").
- Serif document on ivory with a gold top rule and centered official heading.

The review screen shows the whole arc:

- **Workflow stepper:** Draft → Adjutant Review → Commander Approval → Attested →
  Accepted by motion.
- A single slim line stating the AI boundary: **"AI is not the authority."** AI drafts from
  the transcript, aligned to the agenda; uncertainties are surfaced only as the red
  "✎ Fix N" markers, mapped to a short rail review list.
- A role-specific action (e.g., Adjutant's "Send to Commander"), plus honest provenance
  ("not part of the official record until accepted").

## The Sealed / Permanent Record ("Bronze Memorial")

The one place we borrow a second heritage treatment: when a record is approved, attested,
and **accepted by motion** at the next meeting, it becomes a **sealed bronze plaque** —
gold-leaf serif on a dark bronze field, a foil seal, and a snapshot of who approved,
attested, and when it was accepted. It states the immutability rule plainly:

> Sealed and immutable. Corrections are made only by a later amendment — this record is
> never edited.

This ties the visual language directly to the product's core principle: acceptance feels
like carving a name into the wall.

## Audience and Accessibility

- Larger, legible inputs and big primary buttons; plain language; few choices at once.
- Honor the minimum readable sizes above (audience is members in their 70s) — this is a hard
  rule, not a preference.
- Guided, forgiving draft/review states before records become immutable.
- Cream backgrounds over glaring white; high-contrast navy/gold.
- Serif reserved for documents; sans for the working UI (scannability).
- Do not design for power users first.

## Open Items / Deferred

- **Dashboard:** must be redesigned inside this system. The first exploration was rejected
  as a generic "AI dashboard" (card grid + attention queue) and should not be revived
  as-is. Principles to keep: bounded columns, status-with-action, lead with a role-aware
  view of what needs the officer — but find a non-templated layout. Needs its own short
  design pass.
- **Records/archive, Tracked Items index, People, Settings** screens: apply the system;
  not yet mocked.
- **Simplified brand-mark** for tiny emblem sizes.
- **Deco display webfont** selection vs. the system stack.
- **Printed/PDF templates** for finalized agendas and minutes (may borrow an engraved
  "charter" treatment for the printed artifact).

## Implementation Notes

- Define the palette and type as **Tailwind theme tokens**; build the shell (header, nav),
  buttons, status pills, section headers, item rows, the workflow stepper, and the AI-flag
  marker as reusable partials/components so screens compose from one vocabulary.
- Add the official emblem asset(s) to `app/assets/images/`.
- Keep Rails conventional; the design intent above takes precedence over convenience where
  they trade off, but simplify implementation where it does not flatten the experience.
