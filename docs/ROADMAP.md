# Roadmap

This roadmap records current direction. It is expected to evolve as Post 165 uses the app.

## Completed Foundation

- Rails 8.1 application scaffold.
- PostgreSQL-backed domain model.
- First-run setup wizard.
- American Legion Post preset.
- People, users, positions, permissions, organizations, and meeting bodies.
- Passwordless authentication (complete, end-to-end): magic-link email sign-in; passkey
  WebAuthn **registration and sign-in** wired in the browser (feature-detected, with graceful
  fallback to the email link); a first-login "add a passkey" invitation card; and a
  Profile page to name, rename, and remove passkeys. Dev email is viewable via
  `letter_opener_web`; production email runs behind a replaceable delivery boundary (Loops.so).
  See `docs/superpowers/specs/2026-07-11-authentication-flow-design.md`.
- Compact authenticated app shell (header) + minimal authenticated dashboard.
- Visual design system — "The 1919" Art Deco direction with palette, typography, component
  vocabulary, and a readability hard rule (`docs/superpowers/specs/2026-07-11-visual-design-system-design.md`).
- Styled sign-in and magic-link confirmation screens on a dedicated entry layout, using the
  official American Legion emblem and a configurable organization identity (name + locality).
- Roster-backed administration: admin section, National roster CSV import keyed by Member ID,
  dated read-only roster fields with 30-day freshness warnings, people/member list and detail
  views, person-to-user login management, app permission assignment, post role assignment with
  effective dates, and roster/login email mismatch review. See
  `docs/superpowers/specs/2026-07-11-admin-and-roster-import-design.md`.

## Current Documentation Foundation

- README for operators and repo visitors.
- Agent instructions.
- Purpose, users, architecture, roadmap, deployment notes, and Endeavor governance.

## Production Readiness Side-Roadmap

As a bounded operational track, prepare the first real production installation for Robert E. Burns Post 165. This does not replace Structured Agendas as the next core product workflow.

Completed for the first production setup:

- Configured `members.wipost165.org` on the shared Hetzner VPS as a separate Kamal service.
- Used install-specific names such as `legion_post_165_wi_tools` for service, databases, and volumes.
- Provisioned a dedicated PostgreSQL accessory and Active Storage volume for this install.
- Followed persistent SSH control-master discipline before Kamal and SSH-heavy production work, then tore the connection down afterward.
- Completed first-run setup for Robert E. Burns Post 165.
- Verified HTTPS app availability, health check, production magic-link delivery, production magic-link sign-in, and administrator dashboard access on the real hostname.
- Verified production passkey registration and passkey sign-in.
- Verified roster import and admin access-control workflows.
- Verified that `request.remote_ip` resolves to the real client IP behind the Kamal proxy.
- Confirmed the co-hosted TwoRiversReporter app still responded after deployment.
- Backup and restore are handled as server-side operations outside the application roadmap.
- Updated deployment documentation so the same pattern can later be repeated for another hosted American Legion post or unit without creating a SaaS/multi-tenant app.

Still pending before inviting broader member use:

- Verify storage persistence across a container restart after file-upload workflows exist.

## Completed: Structured Agendas Foundation

With authentication and roster-backed administration in place, build the meeting record core.

Completed for Structured Agendas foundation:

- Organization-owned agenda item catalog with editable local copies.
- Lean regular-meeting baseline seeded from The American Legion Officer's Guide and Manual of Ceremonies.
- Admin management for catalog categories, behavior types, active status, and rich text/script bodies.
- Meeting type templates: seeded PEC Meeting and Membership Meeting, admin-created meeting types, catalog-item picker, template-specific rich text wording overrides, and item ordering/removal.
- Dated agendas: officer-created agendas for actual meeting dates, copied from meeting type templates, editable before approval/publication, with member read-only and printable HTML views.
- Structured agenda sections: reusable section chapters in meeting type templates, copied independently into dated agendas, with guided item placement, accessible ordering controls, and section-aware member/print views.

Still pending:

- Later guided workflow to create a new catalog item from the meeting type/template editor and add it directly to that template.

## Completed: Endeavors Foundation

- Long-lived post business with rich context, importance, raise-by dates, usual meeting
  bodies, and active/completed lifecycle.
- Append-only dated updates and a continuity record that includes agenda appearances.
- Plain-language old-business priority suggestions from active Endeavors.
- Independent Endeavor snapshots added to chosen sections of draft agendas.
- Read access for signed-in members and management through `manage_agendas`.
- A final `endeavor_id` identity seam for future structured minutes items, without making
  meeting wording depend on later Endeavor edits.

See `docs/ENDEAVOR_DEVELOPMENT_PLAN.md` for the completed foundation, the minutes
integration contract, and intentionally deferred Endeavor work.

Still pending:

- Human-confirmed merging or splitting if AI suggestions are added later.

## Completed: Agenda Presentation and Navigation

Completed before beginning the minutes lifecycle:

- Polished member-facing meeting docket and published-agenda document.
- Responsive and print presentation suitable for reading at a meeting or distributing
  as a printed handout.
- Primary navigation links only to working features, including member Meetings access.
- Active-state, permission, keyboard, desktop, and phone-width verification.
- See `docs/AGENDA_PRESENTATION.md`.

## Completed: Commander Working Copy and Officer Roll Call

- Independent controls for wording shown on member agendas and carried into draft minutes.
- Private rich-text Commander scripts copied through catalog, template, and dated snapshots.
- Separate member and Commander print documents with no private-content leakage.
- Meeting-date officer roll-call snapshots with required-office vacancies and deliberate
  draft refresh.
- Compact Present, Absent, and Excused worksheet treatment for desktop, phone, and print.
- See `docs/COMMANDER_AGENDA_AND_ROLL_CALL.md`.

## Completed: Officer Agent Operability

Let Grok Bot (and later a similar machine-resident agent) operate the app as a
delegate for the particular signed-in member, using that user's current grants.
When the member holds an assigned office, the generated instructions identify it;
otherwise they identify the user as a post member. The Bot does the thinking. The
app stays a predictable operations tool.

Immediate jobs this phase must unlock:

- Explicit orders such as “create a basic PEC agenda for next Tuesday” and
  “add the car show topic to the next meeting agenda.”
- Morning group-chat triage **in Grok Bot**, which then creates or updates
  Endeavors and draft agenda entries here. Chat never enters this app.

Grok Bot is intended to be the signed-in user's delegate for ordinary work, not a
weaker integration account. Browser sessions and personal agent tokens are credential
choices; either represents the user's current delegated grants. Official minutes are different:
approval, attestation, signature, acceptance, and amendment will require app-enforced
proof of fresh human intent that the Bot cannot infer or create for itself.

Build:

- Private session-or-bearer JSON for meeting bodies, meeting types, the agenda catalog,
  dated agendas and their items, dated officer-list snapshots, and Endeavors. Same
  `can?` rules as the HTML app.
- Generated handbook at `GET /api` (login required) so the Bot can learn this
  installation without a human manual, MCP, or public docs. Standing
  instructions to paste into the Bot live in `docs/agent-operator-skill.md`
  (what the app is, URL, sign-in, then `/api`). Job routines stay in the Bot.
- Lists, not search. The Bot matches names from the list.
- A guided historical-business workflow that lists before creating, targets exact section
  ids, uses standalone dated rows for one-meeting business, links long-lived business to
  Endeavors without duplication, and explicitly reorders each changed section from the
  officer-supplied complete order.
- Destructive and snapshot-reset actions appear separately under **Only when asked**.
- Draft-only creates unless the human explicitly asks to approve or publish.
- Verify the Agent Computer browser can sign in and reach `/api` (watch
  `allow_browser`).
- Bearer-authenticated mutations require persisted idempotency keys and record agent-token
  execution provenance.
- Before any official-minutes mutation is exposed to an agent, add one-use,
  record-and-action-bound human confirmation plus agent-execution audit provenance.

The first slice deliberately did not build TUI, CLI package, MCP, public `llms.txt`,
chat ingest, or minutes endpoints. The completed access phase added personal agent
tokens without adding those broader protocol surfaces.

See `docs/superpowers/specs/2026-08-22-officer-agent-operability-design.md`,
`docs/superpowers/plans/2026-08-22-officer-agent-operability.md`, and
`docs/superpowers/specs/2026-08-29-agent-agenda-api-parity-design.md`.

When minutes, PDF, or distribution ship, add them to the handbook. MCP still waits
until connector-style onboarding is worth another protocol surface.

## Completed: Agent Sign-in and Access

- Added a browser-bound, eight-digit code to the same email as the one-click link.
- Added Profile-managed, named, expiring, revocable personal agent tokens, plus
  administrative revocation without impersonation.
- Token creation requires recent human authentication.
- Token-authenticated mutations require idempotency keys and record execution provenance.
- `/api` adapts to session or bearer authentication, and Agent access generates a
  personalized, copyable standing brief that directs the Bot to reread `/api` each session.
- Code sign-in, token access, revocation, negative security cases, and desktop/phone UI
  were verified before deployment.

See `docs/superpowers/specs/2026-08-22-agent-sign-in-and-access-design.md` and
`docs/superpowers/plans/2026-08-22-agent-sign-in-and-access.md`.

## Completed: Meeting Foundation and Member Archive

The first validation case is concrete: an already-held Post meeting has one structured
agenda and an available recording transcript. The first-class Meeting and member archive
foundation is complete: officers can create occurrences before their documents, agendas
belong to Meetings with historical heading/place snapshots, members can browse upcoming
and past Meetings, and the private API follows the same boundary.

The governing foundation design is
`docs/MEETING_FOUNDATION_AND_MEMBER_ARCHIVE.md`.
It settles the first-class Meeting boundary, historical document snapshots, member
archive, time-zone handling, and the future minutes states that the archive must present
honestly.

### Completed Slice 1: First-class Meeting and member archive

- Add an organization-owned `Meeting` as the durable occurrence, with its meeting body,
  optional meeting type, local date/time, title, and snapshotted venue name/address. A
  saved Meeting is visible to signed-in members even when it has no published agenda; do
  not add a second meeting-publication workflow in this private member app.
- Add an installation-configured time zone for entry and display while storing timestamps
  in UTC. Historical evening meetings must not move to the wrong local date.
- Give each `DatedAgenda` one unique, required `meeting_id` after a safe backfill, and make
  future agenda creation begin from a Meeting. A Meeting may exist before an agenda is
  created or published, but an agenda may not exist without its Meeting.
- Keep Meeting schedule/place data separate from the agenda's historical document snapshot.
  Creating an agenda copies the Meeting heading and venue. Draft agenda details may follow
  deliberate Meeting edits, but approved or published agenda wording must never be silently
  rewritten.
- Build **Administration -> Meetings** as the officer workspace: create or backfill a
  Meeting, edit its date/time/place, and create or open its agenda. Use the effective
  Meeting Body/organization venue as editable defaults and snapshot the submitted values;
  do not introduce a reusable Places subsystem.
- Rebuild member Meetings around occurrences: a prominent next meeting, other upcoming
  meetings, and a reverse-chronological record of past meetings. Every row opens a Meeting
  page, so “Agenda not published yet” remains useful rather than becoming a dead end.
- Show the best available record prominently: no published agenda, published agenda,
  attested minutes awaiting acceptance, or accepted official minutes. When minutes become
  primary, retain the published agenda as quieter historical evidence.
- Update the private Meeting/agenda API and generated handbook in the same slice so an
  authorized delegated agent cannot bypass the first-class Meeting boundary.

## Next Core Work: Structured Minutes Lifecycle

The detailed governing design is `docs/MINUTES_LIFECYCLE.md`. Build the next slices so the
web app can use the historical Meeting, agenda, and transcript as distinct sources to
prepare an OpenAI-generated structured first pass; let the Adjutant correct it without
inventing missing facts; and carry one exact revision through human review, attestation,
later acceptance, and immutable correction history.

Do not attach minutes directly to a dated agenda or make the agenda stand in for the
Meeting. Build the structured editor and AI generation in the same slice: the editor is
the safe correction foundation and manual fallback, while the generated first pass is the
normal Adjutant experience.

### Slice 2: Private source material and structured draft minutes

- Add one optional `Minutes` record per Meeting, with structured `MinutesSection` and
  `MinutesItem` children rather than one large rich-text document.
- Seed a draft from the linked agenda by copying section/item wording, behavior intent,
  source `dated_agenda_item_id`, and optional direct `endeavor_id`. All copied wording is
  an independent minutes snapshot.
- Permit standalone minutes items for unplanned business. Never infer an Endeavor from a
  copied title or classification; a human must confirm any new identity link.
- Carry the dated officer-list snapshot into minutes attendance, then record actual
  Present, Absent, and Excused results in minutes-owned rows. Do not mutate the published
  agenda worksheet.
- Represent substantive outcomes as structured content attached to a minutes item. The
  initial design must cover narrative, motions/decisions, mover and seconder snapshots
  when known, and the recorded outcome without attempting a general parliamentary engine.
- Accept transcript paste first and a narrowly supported text-file upload when useful.
  Treat the transcript as restricted source material, separate from the official minutes,
  excluded from member and print output, and governed by an explicit retention/deletion
  decision before production use.
- Implement the manual editor first as the safe domain foundation and fallback, then make
  an OpenAI-generated first pass the primary Adjutant path before Slice 2 is complete. Use
  strict structured output behind a replaceable provider boundary; record prompt,
  source/run, and review provenance; surface uncertainty; and never invent attendance,
  motions, seconds, votes, decisions, or Endeavor identity.

### Slice 3: Human review, approval, and attestation

- Keep the MVP state machine small: `draft` -> `approved` -> `attested` -> `accepted`.
  Review is an activity within draft, not a separate persisted status unless officer use
  proves a handoff state is necessary.
- `manage_minutes` controls drafting. Commander approval, Adjutant attestation, and later
  acceptance recording use the existing explicit capabilities rather than inferred job
  titles or administrator power. Rename the unused motion-specific acceptance capability
  to `record_minutes_acceptance` before it is used by this workflow.
- Attested minutes become the member-visible pre-acceptance record. An explicit reopen may
  return approved or attested minutes to draft, but it must preserve who reopened them and
  when, invalidate the superseded approval/attestation, and require the human workflow
  again.
- Approval, attestation, signature-equivalent confirmation, and acceptance require fresh,
  one-use, record/action/version-bound human intent. Reuse the current passkey-preferred,
  email-code fallback reauthentication boundary where appropriate, but do not treat a
  browser session or bearer token alone as proof.
- Do not expose official-record mutations to an agent until the confirmation record and
  agent-execution provenance exist. Agents may help create and edit drafts within the
  signed-in user's grants; they cannot make a record official.

### Slice 4: Acceptance, amendments, and immutability

- Record acceptance at a later Meeting of the same body, with the accepting Meeting,
  actor, time, factual disposition, and source minutes item or motion when available. Do
  not require a fictitious motion when the body accepted the minutes as read or corrected.
- Accepted minutes are immutable at the database and application layers. There is no
  administrator bypass and no transition back to draft.
- Corrections adopted during acceptance or discovered later become linked amendment or
  later-meeting records. They do not silently rewrite the attested or accepted text.
- Render the accepted record together with its amendments so readers can see both the
  original historical text and the authoritative correction.
- Present accepted minutes as the primary historical document, attested minutes as
  awaiting acceptance, and the published agenda as a retained secondary document.

### Slice 5: Delivery and delegated access

- Generate the finalized US Letter minutes PDF from the shared print-first meeting
  document system after the official lifecycle is correct.
- Add email distribution and delivery records after final document generation is stable.
- Add draft-minutes API and generated-handbook guidance only after the HTML workflow is
  proven. Add official-action API surfaces only with the same one-use human confirmation,
  idempotency, and execution audit required by the browser workflow.

The guided catalog-item creation improvement, Endeavor merge/split tools, Four Pillars,
events, assignments, dashboards, reminders, general document archives, and broad AI
automation do not block these minutes slices.

## Deployment

- Longer-term deployment hardening beyond the Production Readiness Side-Roadmap.
- Harden Kamal production deployment for repeatable future installs.
- Expand deployment automation and operational checks for additional American Legion posts or units.

## Security and Account Continuity

- Full session/device management system on Profile: list signed-in browsers/devices,
  show last seen/browser/IP context, revoke one session, sign out all other
  sessions, clean up sessions after 180 days of inactivity, revoke sessions on risk
  events, and later support step-up authentication for sensitive actions.

## Later Possibilities

- Installation settings administration, including a guided time-zone change that previews
  affected Meeting and historical document times, requires explicit confirmation, and
  migrates stored timestamps without silently moving their intended local date or clock time.
- Document archive.
- Committee tracking.
- Calendar/events.
- Lightweight finance records.
- Officer/member directory.
- Public read-only API for selected approved records (distinct from the private
  officer-agent API).
- Personal access tokens or MCP wrapping that private API, if a future agent
  cannot use the session-authenticated handbook.
