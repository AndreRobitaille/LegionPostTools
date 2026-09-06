# Endeavor history reading design — September 6, 2026

The first live histories exposed a presentation failure: full meeting accounts, repeated
dated citations, duplicate motion wording, and source controls were all stacked at the
same visual weight. The short synthetic browser example did not reveal the actual load.

## Reading hierarchy

The page's job is to let a Post member understand progress in under a minute, then choose
which meeting to explore. Keep the existing The 1919 palette: navy #0A2240, cream #F4EEDD,
paper #FBF7EC, gold #C6A15B, and ink #1b222b. Use the established sans-serif body at 17px,
restrained Georgia for source quotations, and 14px metadata. Interactive labels remain
at least 16px. Date columns, outcome counts, and disclosure labels convey actual content.

```
Title / status
At a glance                       Endeavor details / officer actions
  short overview with compact source links
Meeting history
  SEP 01  Membership meeting   6 updates · 1 decision  [Read updates]
  JUL 07  Membership meeting   3 updates              [Read updates]
Background and context [expand]
Add an officer update [expand, officers only]
```

Keep the whole overview visible. Meeting accounts begin collapsed; their dates, meeting
names, record authority, update counts, and decision counts remain visible. Opening one
reveals an airy bullet list of complete claims, grouped into recorded decisions and
discussion. Decisions are identified by citations to actual source outcomes, not keyword
guesses or new AI calls. Source passages and exact motions have
a separate disclosure within that meeting, avoiding immediate duplication. If no AI
account exists, opening the meeting shows the original entries directly.

Native details/summary supports keyboard and touch without new JavaScript. The summary
row has an explicit action label and visible focus. Do not truncate text with line-clamp,
remove facts, create new summaries, or rerun AI. Keep current citations and source text.
On narrow screens the history precedes administrative metadata, with no sticky rail.
Officer updates, update forms, and long background context begin collapsed. When an AI
overview exists, the older manual description joins the background rather than competing
with current history at the top. Completed Endeavors omit the old urgency label.

## Critique and verification

An always-open latest meeting would still make long election minutes dominate the page;
all meeting accounts therefore begin closed. A grid of summary cards would fragment an
80-word overview; keep it one quiet paper panel instead. Do not add decorative stats or
color-code AI claims as if they were task status.

Validate with the actual live election, Car Show, and Newsletter histories at desktop and
390px, including opening the longest meeting, reading its evidence, keyboard focus,
source navigation, and overflow. Preserve access controls and stored AI editions.


## Verified locally

The live Car Show, election, and Newsletter editions were checked at 1440px and 390px.
All history disclosures begin closed. The longest meeting retains all 13 generated claims,
grouped into decisions and discussion, with all four original election motions accessible
in the evidence disclosure. Native keyboard activation and visible focus pass, and no
horizontal overflow was found. Officer forms are collapsed and metadata follows history
on mobile. Compact citations still navigate to the exact item in the full minutes.

Focused verification: 31 tests, 178 assertions, no failures/errors/skips; focused RuboCop
(two files), Tailwind build, and diff whitespace checks pass. Existing AI editions were
reused without additional model calls. The developer's server on port 3000 was left running.

## Source reader and richer navigation

The next iteration adds a native dialog: right-side reader on desktop and full-screen
sheet on mobile. Its sticky header has Close; Escape and desktop backdrop clicks dismiss
it. Focus returns to the triggering source link, with underlying scroll preserved. Source
links are descriptive sub-bullets beneath claims, with ordinary navigable URLs as a
no-JavaScript fallback. Fetch each excerpt when opened; serve only current member-visible,
Endeavor-related source units. Cross-organization, stale, withdrawn generated-only, and
unrelated unit requests fail closed. Render escaped source text and complete motion data.

Prompt version 2 adds a cited headline per meeting and a short title per relevant source
outcome. Verify these along with the summary. The overview leads with the latest recorded
position and explains earlier context second; its coverage date remains explicit. Older
editions remain readable with ordinary meeting/source headings until refreshed. Never
manufacture titles by truncating or guessing from prose.

Decision cards use the original disposition and accessible text/symbols; colors alone
never carry meaning. The full motion and vote remain in the source reader. Public page
navigation links to overview, history, and background. Provenance moves into background;
editing, completion, AI administration, internal priority/reason, and update forms remain
behind the existing manage_agendas capability in both the UI and mutation endpoints.
This retains Commander/Adjutant, administrator, and explicit capability-grant semantics.

### Source-reader verification

Implemented and checked with the three refreshed live editions at 1440px and 390px.
Close, Escape, and desktop backdrop dismissal restore focus and underlying scroll;
navigation to full minutes and browser Back leaves the dialog closed and scrolling
unlocked. The mobile reader shows one requested motion with its complete vote details,
and neither viewport has horizontal overflow. Members see public navigation without
officer tools, internal priority, or update forms; managers retain those controls.

Direct-request tests cover exact-unit isolation, unrelated units, stale revisions,
cross-organization access, approved-but-unattested records, withdrawn generated-only
sources, authentication, and privileged mutations. Source responses are private/no-store;
unavailable sources receive a plain 404 page.

Final verification: 874 tests, 5,515 assertions, no failures/errors/skips. Focused RuboCop,
JavaScript syntax, Tailwind build, and diff whitespace checks pass; Brakeman reports zero
warnings. Handbook checks additionally pass with 10 tests and 251 assertions. Live AI
refresh results and the observed automatic repair are recorded in
`docs/ENDEAVOR_HISTORY_AI_LIVE_EVALUATION.md`. The developer's port-3000 server remains running.
