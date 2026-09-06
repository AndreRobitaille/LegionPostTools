# Endeavor Member History and Future Coordination

**Status:** exploration, September 6, 2026. Recommendations for discussion, not an
implemented feature or authorization to change meeting records or run paid AI generation.

**Superseded recommendation:** after inspecting the actual minutes, the user selected a
full first version with automatic AI discovery, summaries, and publication, plus admin
reruns and clarifying guidance. The earlier staged/reviewed approach below is retained
as exploration history, not the current implementation direction. See the
[current design](ENDEAVOR_HISTORY_AI_DESIGN.md) and
[implementation plan](ENDEAVOR_HISTORY_AI_IMPLEMENTATION_PLAN.md).

## Purpose and recommendation

An American Legion member opening an Endeavor should quickly understand what the work
is, what the Post has recorded about it, and when it will next come before a meeting.
The same history should help incoming officers understand decisions made before their term.

Build a member-readable history from the relevant published meeting records first.
Show the actual recorded minutes and outcomes, grouped by meeting, with a separate
upcoming-agenda area. Later, consider a short AI-assisted overview above that history
if members find a long record difficult to follow. The overview would supplement the
source record and would never acquire the authority of minutes.

This fits the continuity purpose in [Endeavor governance](ENDEAVOR_GOVERNANCE.md).
Future coordination tools can grow around the same durable Endeavor identity; they
need a separate design before expanding the current governance scope.

## What exists today

Verified against the local implementation during this exploration:

- `Endeavor` has background, summary, active/completed state, append-only officer
  updates, linked dated-agenda items, and linked structured minutes items.
- `EndeavorsController#build_timeline` combines updates and agenda appearances. It
  does not include minutes text or minutes-only business. Future and past appearances
  are mixed together in reverse chronological order.
- `MinutesItem` has an optional `endeavor_id`, an optional source agenda item, and a
  stable `record_key`. Agenda seeding carries the Endeavor link into minutes; officers
  can also link unplanned minutes items. Multiple minutes items can concern one Endeavor.
- `MeetingMinutes#revision_payload` freezes item keys, titles, agenda wording, recorded
  minutes, and structured outcomes. It does **not** freeze `endeavor_id` or the source
  agenda item ID. Live minutes associations alone therefore cannot establish historical
  identity safely when working rows change during corrections.
- Member minutes use `member_revision` and `member_visible?`. Membership-approved
  minutes are official; attested minutes await membership approval. During correction,
  members can still read the last attested revision while officers prepare a new one.
- The current Endeavor document helper tests `attested?` directly, so it does not
  cover all member-visible states, including membership-approved minutes. Timeline
  construction also includes unpublished agenda metadata even when no document link
  is offered. The proposed member view must filter the entries themselves.

Relevant implementation: `app/models/meeting_minutes.rb`, `app/models/minutes_item.rb`,
`app/controllers/endeavors_controller.rb`, `app/helpers/endeavors_helper.rb`, and
`app/views/meeting_minutes/_revision.html.erb`.

## Two approaches to telling members what happened

| Approach | Member benefit | Cost and limitations |
| --- | --- | --- |
| Relevant minutes and outcomes | Members see exactly what was recorded, with dates and source links. Available without an additional AI call. | A long history still takes reading; recorded wording may be formal. Correct linking and revision selection are required. |
| AI overview across meetings | A short account of progress can connect decisions across several meetings. | Can omit qualifications or confuse proposals with decisions. Requires source citations, refresh rules, review, evaluation, and ongoing generation cost. |
| Combined approach | A brief overview provides orientation while the complete relevant history remains available below. | Inherits the AI maintenance burden, but retains a useful page when the overview is absent or outdated. |

**Recommended sequence:** direct history first, then evaluate the combined approach.
Generating an AI paraphrase of every meeting entry adds little when the relevant minutes
are already concise. The stronger AI use case is synthesis across a lengthy history.

The existing human-written Endeavor summary should continue explaining what the Endeavor
is. Do not silently replace it with a generated status report. Officer updates remain a
useful way to report developments between meetings, explicitly attributed to their author.

## Proposed member experience

The page answers three questions in order: “What is this?”, “What is coming up?”, and
“What has happened?” An optional future overview would answer “Where do things stand?”
immediately after the introduction.

```text
Car show                                      Still tracking
Background summary explaining this Endeavor

[Optional later: At a glance — through September 1]
Short reviewed overview with links to its sources

COMING UP
October 6 · Membership meeting                View agenda
On the published agenda: Event planning report

HISTORY
September 1 · Membership meeting
Attested minutes · Awaiting membership approval
Recorded minutes
  [The relevant passage, as recorded]
Motion · Carried
  [Exact motion and recorded result]
View full minutes

August 20 · Update from [officer name]
  [Attributed update]

August 4 · Membership meeting
Listed on the published agenda · Minutes not available yet
View agenda
```

This is illustrative content, not a claim about an actual Post meeting.

- Use **History**, replacing the officer-oriented “Continuity” heading and empty copy.
- Separate future published appearances, earliest first, from history, newest first.
  Completed Endeavors retain their history; any actual future published appearance still
  appears rather than being hidden because the Endeavor is complete.
- Group all related minutes items from one meeting under its date and meeting body;
  keep item order and source titles. An agenda appearance and its minutes become one
  meeting entry, with minutes as the primary source once available.
- Include minutes-only business even when it never appeared on an agenda.
- Render the recorded body and outcomes, preserving motions, dispositions, vote details,
  and qualifications. Agenda wording is planned business, not evidence of what happened.
  Keep it clearly labeled and secondary when useful for context.
- Show short entries in full. For long entries, use an explicit **Read more from these
  minutes** disclosure exposing the complete relevant material. Do not silently truncate
  a motion or hide its disposition while showing its proposal.
- Label an agenda-only past entry **Listed on the agenda**, never “Discussed,” unless
  minutes actually establish discussion. Missing minutes do not mean nothing happened.
- If visible minutes contain a linked item with no recorded body or outcomes, say
  **No discussion or outcome recorded for this item**. If no confirmed linked passage
  exists, say **No linked minutes entry available**, and offer the full visible minutes.
- Preserve “Awaiting membership approval,” “Official minutes,” and “Correction in
  progress” distinctions from the meeting page. A corrected attested revision replaces
  the displayed excerpt through the same member revision selector.
- Members see published agendas and member-visible minutes only. Officer planning
  metadata, private transcripts, working drafts, and AI review notes do not enter this
  history or an AI overview. Officer updates are labeled separately from meeting records.

### Visual direction

Use The 1919 system: navy `#0A2240`, gold `#C6A15B`, cream `#F4EEDD`, paper `#FBF7EC`,
and ink `#1B222B`. System sans carries navigation and explanations; Georgia is reserved
for clearly bounded source-document excerpts. Reuse section headers, date treatments,
status words, and the existing history list rather than introducing a dashboard card grid.

The distinctive element is a dated meeting entry with its recorded passage, authority
label, and source action kept together. History is the main column; background/facts may
occupy a quiet desktop rail. Upcoming business stays in the reading flow. At 390px the
page becomes one column, with secondary facts following the history. Preserve the 16px
body/control, 14px secondary, and 13px label floors and existing responsive breakpoints.

Design critique: a board-first layout would make members learn a workflow before finding
the record they came to read. A chronological history supports the immediate purpose.
Long minutes passages need progressive disclosure without obscuring decisions. This is
a written layout proposal; rendered desktop, narrow-width, keyboard, and overflow review
remain implementation acceptance work.

## Reliable source links and implementation boundaries

1. Freeze the confirmed Endeavor identity with each item in **new** approved revision
   payloads. Include source agenda identity if useful for navigation. Existing immutable
   payloads and digests must remain untouched.
2. For older revisions, design a separate, audited association from revision/item key to
   Endeavor. A human confirms proposed links. Existing direct links can supply candidates;
   title similarity cannot establish identity. Do not read a changed live draft link as
   if it were the original approved association. Until confirmed, retain agenda history
   and full-document navigation without claiming a matched excerpt.
3. Select sources within the signed-in member's organization and current document
   visibility. Use the member revision selector for content and its identity association,
   not the latest working `MinutesItem`. During corrections the last attested text and
   its links remain the source until the replacement becomes member-visible.
4. Build a small shared history query/presenter with stable meeting/item identifiers.
   Reuse sanitized revision rendering for body and structured outcomes. Add stable item
   anchors to full minutes so a source link can take the member to the relevant passage.
5. Derive the history from records, rather than copying minutes into `EndeavorUpdate`.
   Pagination must preserve meeting grouping and ordering. Cache keys, if needed, must
   include source revision, link changes, visibility, and membership-approval state.
6. Keep any external historical association correction auditable and separate from
   corrections to the minutes themselves. No feature here changes approval authority,
   accepted text, Endeavor completion, or meeting outcomes automatically.
7. Consider additive read API history parity using the same selector. The current API
   exposes summary/detail and upcoming IDs, not this history. Check unpublished metadata
   filtering in HTML and API together; do not introduce a new write API for this slice.

The older-revision association workflow is a substantive part of scope, not a data repair
to perform during this exploration. Check actual coverage before estimating rollout work.

## Optional AI overview design

If direct history proves insufficient, prototype a short overview from only confirmed,
member-visible linked minutes. Start with minutes alone; adding officer updates later
requires explicit attribution and rules for resolving contradictory sources.

- State the coverage: **Based on meeting records through [date]**. This is evidence of
  recorded progress, not a guarantee of today's operational status.
- Link each substantive claim to its meeting/revision/item. Distinguish discussed,
  proposed, approved, deferred, and completed; silence is not proof of completion.
- Describe recorded next steps only when sources say so. Never infer a volunteer,
  assignment, deadline, expenditure authorization, or current task state.
- Recommend an officer-reviewed publication path for the first version. Label it
  **AI-assisted overview · Reviewed by [name] · [date]** and explain that source minutes
  govern. Review of an overview is separate from official minutes approval/attestation.
  The reviewer capability needs a deliberate decision; do not inherit official authority.
- Store generated versions, source revision IDs/digests and item keys, prompt/model
  versions, generation time, reviewer, and publication time. Keep citations resolvable.
- New source material makes an overview outdated. Mark it as such while history updates
  immediately. If a correction changes a cited source or a source becomes inaccessible,
  withdraw the affected overview until reviewed again. Never keep unauthorized content
  visible merely because it was cached or summarized earlier.
- Generate in background on a bounded, deduplicated basis; never on every page visit.
  A failed run leaves the direct history usable. Do not automatically publish a refresh
  under an earlier reviewer's name.
- Before adoption, evaluate synthetic cases for changed decisions, defeated motions,
  several meeting bodies, ambiguous ownership, corrected revisions, and missing records.
  Require supported claims and useful compression, then measure review effort and cost
  on explicitly authorized sample data. No provider/model choice is needed yet.

## Future roadmap: coordination around active Endeavors

These are exploration topics, not commitments to build a general project-management
suite. Add them when a concrete Post workflow justifies the upkeep.

| Possible step | Questions to resolve before implementation |
| --- | --- |
| What needs to be done | Who maintains a current next-step list? How are recorded commitments distinguished from present operational work? |
| Who is working on it | Who may assign or accept responsibility? How do dated assignments survive turnover? A speaker or mover is not automatically the responsible person. |
| Subcommittee and participants | Who establishes the group, chair, scope, and term? How are official appointments distinguished from informal volunteers, and who can see contact details? |
| Task lists | Start with a simple accessible list, owners, optional dates, and completion history. Decide assignment, editing, and completion permissions before adding dependencies. |
| Volunteer requests | Define the actual need, coordinator, sign-up/withdrawal flow, capacity, member visibility, and notification consent. Avoid exposing private contact data. |
| Kanban view | Consider only if a task list no longer explains progress. Define useful Post-specific states and provide buttons/list alternatives to dragging, especially on phones. |

Current coordination belongs in a future **Work and volunteers** area. Meeting history
remains available for active and completed Endeavors. Task completion does not complete
the Endeavor or change a meeting decision; Endeavor completion does not erase unfinished
work. Those transitions need explicit future rules. No empty task/board placeholders
should appear in the first member-history release.

## Suggested delivery slices and acceptance evidence

1. **Direct history:** settle immutable identity capture and legacy association handling;
   implement grouped excerpts, outcomes, upcoming published agendas, and visibility rules.
2. **Readability review:** have members try finding the latest decision and next meeting.
   Assess whether long histories actually need an overview.
3. **Optional overview:** evaluate generation quality, review workload, refresh behavior,
   and cost before adopting the combined approach.
4. **Coordination discovery:** investigate next steps and people first, then task lists
   and volunteering; assess a board only after those workflows exist.

Implementation checks should cover minutes-only items, several items per meeting,
agenda-only entries, future publication filtering, completed Endeavors, organization
isolation, sanitized rich text, deterministic ordering, and source anchors. Lifecycle
checks must cover initial draft, approved but unattested, attested, membership-approved,
reopened, corrected approval awaiting attestation, and re-attested revisions. Verify
old payloads/digests remain unchanged and mutable draft edits cannot alter member excerpts
or their associations. Review HTML/API visibility, query scaling, and desktop/390px UX.

Open product choices are the scope of legacy link confirmation, whether direct history
is sufficient, and—if AI is adopted—who reviews the overview and which sources it may use.
Recommended defaults above make these choices concrete without treating exploration as
implementation approval.
